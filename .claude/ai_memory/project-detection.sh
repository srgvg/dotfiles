#!/bin/bash

# Project Detection and ID Generation Script
# Implements enhanced project detection hierarchy with hash-based unique IDs

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MEMORY_BASE="${MEMORY_BASE:-$HOME/.claude/ai_memory}"

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

debug() {
    [[ "${DEBUG:-0}" == "1" ]] && log "${BLUE}DEBUG: $1${NC}"
}

info() {
    log "${BLUE}INFO: $1${NC}"
}

warning() {
    log "${YELLOW}WARNING: $1${NC}"
}

success() {
    log "${GREEN}SUCCESS: $1${NC}"
}

error() {
    log "${RED}ERROR: $1${NC}"
    return 1
}

# Function to generate project hash
generate_project_hash() {
    local project_path="$1"
    local git_remote="${2:-}"
    local project_name="${3:-}"
    
    # Combine inputs for hash (absolute path is most important for uniqueness)
    local hash_input="${project_path}${git_remote}${project_name}"
    
    debug "Hash input: $hash_input"
    
    # Generate 4-character hash
    echo "$hash_input" | sha1sum | cut -c1-4
}

# Function to normalize project names
normalize_project_name() {
    local name="$1"
    
    # Convert to lowercase, replace invalid characters with hyphens
    echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g'
}

# Function to detect git information
detect_git_info() {
    local project_path="$1"
    local git_dir=""
    local git_remote=""
    local project_name=""
    local is_worktree=false
    
    if [[ -d "$project_path/.git" ]]; then
        # Standard git repository
        git_dir="$project_path/.git"
        debug "Found standard git repo: $git_dir"
    elif [[ -f "$project_path/.git" ]]; then
        # Git worktree - .git file points to main repo
        is_worktree=true
        local git_file_content=$(cat "$project_path/.git")
        git_dir=$(echo "$git_file_content" | sed 's/^gitdir: //')
        
        # Convert relative path to absolute if needed
        if [[ ! "$git_dir" =~ ^/ ]]; then
            git_dir="$project_path/$git_dir"
        fi
        
        debug "Found git worktree: $git_dir"
        
        # For worktrees, we need to find the main repo
        local main_git_dir=$(dirname "$git_dir")
        if [[ -f "$main_git_dir/config" ]]; then
            git_dir="$main_git_dir"
        fi
    fi
    
    if [[ -n "$git_dir" && -f "$git_dir/config" ]]; then
        # Try to get remote URL
        if command -v git >/dev/null 2>&1; then
            git_remote=$(cd "$project_path" && git remote get-url origin 2>/dev/null || echo "")
        else
            # Fallback: parse config file directly
            git_remote=$(grep -E "^\s*url\s*=" "$git_dir/config" | head -1 | sed 's/.*url\s*=\s*//' | tr -d ' ' || echo "")
        fi
        
        debug "Git remote: $git_remote"
        
        # Extract project name from remote URL or directory
        if [[ -n "$git_remote" ]]; then
            project_name=$(basename "$git_remote" .git)
        else
            project_name=$(basename "$project_path")
        fi
        
        debug "Git project name: $project_name"
    fi
    
    echo "$git_remote|$project_name|$is_worktree"
}

# Function to detect package manager files
detect_package_info() {
    local project_path="$1"
    local package_name=""
    local package_type=""
    
    # Node.js - package.json
    if [[ -f "$project_path/package.json" ]]; then
        package_type="nodejs"
        if command -v jq >/dev/null 2>&1; then
            package_name=$(jq -r '.name // empty' "$project_path/package.json" 2>/dev/null || echo "")
        else
            # Fallback: grep for name field
            package_name=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$project_path/package.json" | sed 's/.*"\([^"]*\)".*/\1/' || echo "")
        fi
        debug "Found package.json: $package_name"
    fi
    
    # Rust - Cargo.toml
    if [[ -f "$project_path/Cargo.toml" && -z "$package_name" ]]; then
        package_type="rust"
        package_name=$(grep '^name[[:space:]]*=' "$project_path/Cargo.toml" | head -1 | sed 's/.*=[[:space:]]*"\([^"]*\)".*/\1/' || echo "")
        debug "Found Cargo.toml: $package_name"
    fi
    
    # Go - go.mod
    if [[ -f "$project_path/go.mod" && -z "$package_name" ]]; then
        package_type="go"
        package_name=$(grep '^module' "$project_path/go.mod" | head -1 | awk '{print $2}' | sed 's|.*/||' || echo "")
        debug "Found go.mod: $package_name"
    fi
    
    # Python - pyproject.toml
    if [[ -f "$project_path/pyproject.toml" && -z "$package_name" ]]; then
        package_type="python"
        package_name=$(grep '^name[[:space:]]*=' "$project_path/pyproject.toml" | head -1 | sed 's/.*=[[:space:]]*"\([^"]*\)".*/\1/' || echo "")
        debug "Found pyproject.toml: $package_name"
    fi
    
    # Python - setup.py (fallback)
    if [[ -f "$project_path/setup.py" && -z "$package_name" ]]; then
        package_type="python"
        package_name=$(grep -o "name[[:space:]]*=[[:space:]]*[\"'][^\"']*[\"']" "$project_path/setup.py" | sed "s/.*=[[:space:]]*[\"']\\([^\"']*\\)[\"'].*/\\1/" | head -1 || echo "")
        debug "Found setup.py: $package_name"
    fi
    
    # PHP - composer.json
    if [[ -f "$project_path/composer.json" && -z "$package_name" ]]; then
        package_type="php"
        if command -v jq >/dev/null 2>&1; then
            package_name=$(jq -r '.name // empty' "$project_path/composer.json" 2>/dev/null || echo "")
        else
            package_name=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$project_path/composer.json" | sed 's/.*"\([^"]*\)".*/\1/' || echo "")
        fi
        # Remove vendor prefix (e.g., "vendor/package" -> "package")
        package_name=$(echo "$package_name" | sed 's|.*/||')
        debug "Found composer.json: $package_name"
    fi
    
    echo "$package_name|$package_type"
}

# Function to detect build system files
detect_build_info() {
    local project_path="$1"
    local build_system=""
    local has_build_files=false
    
    # Makefile
    if [[ -f "$project_path/Makefile" || -f "$project_path/makefile" ]]; then
        build_system="make"
        has_build_files=true
        debug "Found Makefile"
    fi
    
    # CMake
    if [[ -f "$project_path/CMakeLists.txt" ]]; then
        build_system="cmake"
        has_build_files=true
        debug "Found CMakeLists.txt"
    fi
    
    # Gradle
    if [[ -f "$project_path/build.gradle" || -f "$project_path/build.gradle.kts" ]]; then
        build_system="gradle"
        has_build_files=true
        debug "Found Gradle build file"
    fi
    
    # Maven
    if [[ -f "$project_path/pom.xml" ]]; then
        build_system="maven"
        has_build_files=true
        debug "Found Maven pom.xml"
    fi
    
    # Bazel
    if [[ -f "$project_path/BUILD" || -f "$project_path/BUILD.bazel" || -f "$project_path/WORKSPACE" ]]; then
        build_system="bazel"
        has_build_files=true
        debug "Found Bazel build files"
    fi
    
    echo "$build_system|$has_build_files"
}

# Main project detection function
detect_project() {
    local target_path="${1:-$(pwd)}"
    
    # Ensure absolute path
    target_path=$(realpath "$target_path")
    
    info "Detecting project in: $target_path"
    
    # Initialize variables
    local project_name=""
    local project_id=""
    local detection_method=""
    local confidence=0
    
    # 1. Git Detection (Priority 1-2)
    local git_info=$(detect_git_info "$target_path")
    IFS='|' read -r git_remote git_project_name is_worktree <<< "$git_info"
    
    if [[ -n "$git_project_name" ]]; then
        project_name="$git_project_name"
        if [[ "$is_worktree" == "true" ]]; then
            detection_method="git_worktree"
            confidence=95
            info "Detected git worktree project: $project_name"
        else
            detection_method="git_repository"
            confidence=90
            info "Detected git repository: $project_name"
        fi
    fi
    
    # 3. Package Manager Detection (Priority 3)
    if [[ -z "$project_name" ]]; then
        local package_info=$(detect_package_info "$target_path")
        IFS='|' read -r package_name package_type <<< "$package_info"
        
        if [[ -n "$package_name" ]]; then
            project_name="$package_name"
            detection_method="package_manager_$package_type"
            confidence=85
            info "Detected $package_type project: $project_name"
        fi
    fi
    
    # 4. Build System Detection (Priority 4)
    local build_info=$(detect_build_info "$target_path")
    IFS='|' read -r build_system has_build_files <<< "$build_info"
    
    if [[ -z "$project_name" && "$has_build_files" == "true" ]]; then
        project_name=$(basename "$target_path")
        detection_method="build_system_$build_system"
        confidence=70
        info "Detected $build_system project: $project_name"
    elif [[ -n "$project_name" && "$has_build_files" == "true" ]]; then
        # Enhance confidence if build files are present
        confidence=$((confidence + 5))
        debug "Build system $build_system detected, confidence boosted"
    fi
    
    # 5. Directory Structure Fallback (Priority 5)
    if [[ -z "$project_name" ]]; then
        project_name=$(basename "$target_path")
        detection_method="directory_basename"
        confidence=60
        info "Using directory basename: $project_name"
    fi
    
    # Generate parent directory component for uniqueness
    local parent_dir=$(basename "$(dirname "$target_path")")
    
    # Normalize project name
    project_name=$(normalize_project_name "$project_name")
    parent_dir=$(normalize_project_name "$parent_dir")
    
    # Generate hash for uniqueness
    local hash=$(generate_project_hash "$target_path" "$git_remote" "$project_name")
    
    # Generate project ID
    if [[ "$parent_dir" != "$project_name" && "$parent_dir" != "." ]]; then
        project_id="${parent_dir}-${project_name}-${hash}"
    else
        project_id="${project_name}-${hash}"
    fi
    
    debug "Generated project ID: $project_id"
    
    # Output results as JSON
    cat << EOF
{
  "project_id": "$project_id",
  "project_name": "$project_name",
  "project_path": "$target_path",
  "parent_directory": "$parent_dir",
  "detection_method": "$detection_method",
  "confidence": $confidence,
  "git_remote": "$git_remote",
  "is_worktree": $([ "$is_worktree" = "true" ] && echo true || echo false),
  "build_system": "$build_system",
  "hash": "$hash"
}
EOF
}

# Function to check if project exists in memory
project_exists() {
    local project_id="$1"
    [[ -d "$MEMORY_BASE/projects/$project_id" ]]
}

# Function to create project directory structure
create_project_structure() {
    local project_id="$1"
    local project_info="$2"
    
    local project_dir="$MEMORY_BASE/projects/$project_id"
    
    if [[ -d "$project_dir" ]]; then
        warning "Project directory already exists: $project_dir"
        return 0
    fi
    
    info "Creating project structure: $project_id"
    
    # Create directory structure
    mkdir -p "$project_dir"/{contexts,knowledge,sessions}
    
    # Create project.json
    echo "$project_info" | jq '. + {
        "created": now | strftime("%Y-%m-%dT%H:%M:%SZ"),
        "last_updated": now | strftime("%Y-%m-%dT%H:%M:%SZ"),
        "last_accessed": now | strftime("%Y-%m-%dT%H:%M:%SZ"),
        "structure_version": "2.0",
        "active_contexts": [],
        "statistics": {
            "total_sessions": 0,
            "total_contexts": 0,
            "lines_modified": 0,
            "files_modified": 0
        }
    }' > "$project_dir/project.json"
    
    # Create context index
    cat > "$project_dir/contexts/_index.json" << 'EOF'
{
  "contexts": {},
  "active_contexts": [],
  "paused_contexts": [],
  "completed_contexts": [],
  "last_updated": "",
  "auto_detection_rules": {
    "enabled": true,
    "directory_mappings": {},
    "keyword_mappings": {},
    "git_branch_patterns": {}
  }
}
EOF

    # Create knowledge files
    local knowledge_files=(
        "architecture.json:'{\"decisions\":[],\"patterns\":[],\"constraints\":[],\"last_updated\":\"\"}'"
        "patterns.json:'{\"code_patterns\":[],\"workflow_patterns\":[],\"naming_conventions\":[],\"last_updated\":\"\"}'"
        "dependencies.json:'{\"package_dependencies\":{},\"version_constraints\":{},\"compatibility_notes\":[],\"last_updated\":\"\"}'"
        "technical-debt.json:'{\"debt_items\":[],\"priority_levels\":{},\"resolution_notes\":[],\"last_updated\":\"\"}'"
    )
    
    for file_def in "${knowledge_files[@]}"; do
        local filename=$(echo "$file_def" | cut -d: -f1)
        local content=$(echo "$file_def" | cut -d: -f2-)
        echo "$content" > "$project_dir/knowledge/$filename"
    done
    
    success "Created project structure: $project_id"
}

# Main function
main() {
    local target_path="${1:-$(pwd)}"
    local action="${2:-detect}"
    
    case "$action" in
        "detect")
            detect_project "$target_path"
            ;;
        "create")
            local project_info=$(detect_project "$target_path")
            local project_id=$(echo "$project_info" | jq -r '.project_id')
            
            if project_exists "$project_id"; then
                echo "Project already exists: $project_id" >&2
                exit 1
            fi
            
            create_project_structure "$project_id" "$project_info"
            echo "$project_info"
            ;;
        "exists")
            local project_info=$(detect_project "$target_path")
            local project_id=$(echo "$project_info" | jq -r '.project_id')
            
            if project_exists "$project_id"; then
                echo "true"
                exit 0
            else
                echo "false"
                exit 1
            fi
            ;;
        *)
            echo "Usage: $0 [path] [detect|create|exists]" >&2
            echo "  detect: Detect project information (default)" >&2
            echo "  create: Create project structure if it doesn't exist" >&2
            echo "  exists: Check if project exists in memory" >&2
            exit 1
            ;;
    esac
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi