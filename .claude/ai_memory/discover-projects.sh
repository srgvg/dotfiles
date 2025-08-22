#!/bin/bash

# Project Discovery Script
# Scans directories for projects and creates memory files for those not yet tracked

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MEMORY_BASE="${MEMORY_BASE:-$HOME/.claude/ai_memory}"
SEARCH_ROOTS=("$HOME/src" "$HOME/projects" "$HOME/git" "$HOME/work" "$HOME")
MAX_DEPTH=3

info() {
    echo -e "${BLUE}INFO: $1${NC}" >&2
}

success() {
    echo -e "${GREEN}SUCCESS: $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}WARNING: $1${NC}" >&2
}

# Simple project detection function
detect_project_simple() {
    local project_path="$1"
    local project_name=""
    local project_id=""
    local git_remote=""
    local has_git=false
    local has_makefile=false
    local has_package_json=false
    
    # Get project name from directory
    project_name=$(basename "$project_path")
    
    # Check for git
    if [[ -d "$project_path/.git" ]] || [[ -f "$project_path/.git" ]]; then
        has_git=true
        if command -v git >/dev/null 2>&1; then
            git_remote=$(cd "$project_path" && git remote get-url origin 2>/dev/null || echo "")
            if [[ -n "$git_remote" ]]; then
                project_name=$(basename "$git_remote" .git)
            fi
        fi
    fi
    
    # Check for project files
    [[ -f "$project_path/Makefile" || -f "$project_path/makefile" ]] && has_makefile=true
    [[ -f "$project_path/package.json" ]] && has_package_json=true
    
    # Generate simple hash
    local hash_input="${project_path}${git_remote}${project_name}"
    local hash=$(echo "$hash_input" | sha1sum | cut -c1-4)
    
    # Generate project ID
    local parent_dir=$(basename "$(dirname "$project_path")")
    if [[ "$parent_dir" != "$project_name" && "$parent_dir" != "." ]]; then
        project_id="${parent_dir}-${project_name}-${hash}"
    else
        project_id="${project_name}-${hash}"
    fi
    
    # Clean project ID
    project_id=$(echo "$project_id" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')
    
    echo "${project_id}|${project_name}|${project_path}|${has_git}|${has_makefile}|${has_package_json}|${git_remote}"
}

# Check if project already exists in memory
project_exists() {
    local project_id="$1"
    [[ -d "$MEMORY_BASE/projects/$project_id" ]]
}

# Create basic project structure
create_project_memory() {
    local project_id="$1"
    local project_name="$2"
    local project_path="$3"
    local has_git="$4"
    local has_makefile="$5"
    local has_package_json="$6"
    local git_remote="$7"
    
    local project_dir="$MEMORY_BASE/projects/$project_id"
    
    if project_exists "$project_id"; then
        warning "Project already exists: $project_id"
        return 0
    fi
    
    info "Creating memory for project: $project_id ($project_name)"
    
    # Create directory structure
    mkdir -p "$project_dir"/{contexts,knowledge,sessions}
    
    # Determine project type
    local project_type="unknown"
    [[ -f "$project_path/package.json" ]] && project_type="nodejs"
    [[ -f "$project_path/Cargo.toml" ]] && project_type="rust"
    [[ -f "$project_path/go.mod" ]] && project_type="go"
    [[ -f "$project_path/pyproject.toml" || -f "$project_path/setup.py" ]] && project_type="python"
    [[ -f "$project_path/composer.json" ]] && project_type="php"
    [[ "$has_makefile" == "true" ]] && project_type="make-based"
    [[ "$has_git" == "true" && "$project_type" == "unknown" ]] && project_type="git-repository"
    
    # Create project.json
    cat > "$project_dir/project.json" << EOF
{
  "project_id": "$project_id",
  "project_name": "$project_name",
  "project_type": "$project_type",
  "structure_version": "2.0",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "last_updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "last_accessed": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "location": {
    "root_directory": "$project_path",
    "git_repository": "$git_remote",
    "parent_directory": "$(basename "$(dirname "$project_path")")"
  },
  "technology_stack": {
    "has_git": $has_git,
    "has_makefile": $has_makefile,
    "has_package_json": $has_package_json
  },
  "active_contexts": [],
  "statistics": {
    "total_sessions": 0,
    "total_contexts": 0,
    "lines_modified": 0,
    "files_modified": 0
  },
  "discovery": {
    "discovered_on": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "auto_created": true
  }
}
EOF

    # Create contexts index
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
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    echo "{\"decisions\":[],\"patterns\":[],\"constraints\":[],\"last_updated\":\"$timestamp\"}" > "$project_dir/knowledge/architecture.json"
    echo "{\"code_patterns\":[],\"workflow_patterns\":[],\"naming_conventions\":[],\"last_updated\":\"$timestamp\"}" > "$project_dir/knowledge/patterns.json"
    echo "{\"package_dependencies\":{},\"version_constraints\":{},\"compatibility_notes\":[],\"last_updated\":\"$timestamp\"}" > "$project_dir/knowledge/dependencies.json"
    echo "{\"debt_items\":[],\"priority_levels\":{},\"resolution_notes\":[],\"last_updated\":\"$timestamp\"}" > "$project_dir/knowledge/technical-debt.json"
    
    success "Created memory structure for: $project_id"
    echo "$project_id" # Return project ID for summary
}

# Check if directory looks like a project
is_project_directory() {
    local dir="$1"
    
    # Skip if not readable or is a symlink
    [[ ! -r "$dir" ]] || [[ -L "$dir" ]] && return 1
    
    # Skip common non-project directories
    local basename=$(basename "$dir")
    case "$basename" in
        node_modules|.git|build|dist|target|vendor|venv|__pycache__|.cache|tmp|temp)
            return 1
            ;;
    esac
    
    # Consider it a project if it has any of these indicators
    [[ -d "$dir/.git" ]] && return 0
    [[ -f "$dir/.git" ]] && return 0  # git worktree
    [[ -f "$dir/Makefile" ]] && return 0
    [[ -f "$dir/makefile" ]] && return 0
    [[ -f "$dir/package.json" ]] && return 0
    [[ -f "$dir/Cargo.toml" ]] && return 0
    [[ -f "$dir/go.mod" ]] && return 0
    [[ -f "$dir/pyproject.toml" ]] && return 0
    [[ -f "$dir/setup.py" ]] && return 0
    [[ -f "$dir/composer.json" ]] && return 0
    [[ -f "$dir/pom.xml" ]] && return 0
    [[ -f "$dir/build.gradle" ]] && return 0
    [[ -f "$dir/CMakeLists.txt" ]] && return 0
    
    return 1
}

# Discover projects in a directory
discover_projects_in_dir() {
    local search_dir="$1"
    local current_depth="$2"
    local created_projects=()
    
    if [[ $current_depth -gt $MAX_DEPTH ]]; then
        return 0
    fi
    
    if [[ ! -d "$search_dir" ]]; then
        return 0
    fi
    
    info "Scanning: $search_dir (depth $current_depth)"
    
    # Check if current directory is a project
    if is_project_directory "$search_dir"; then
        local project_info=$(detect_project_simple "$search_dir")
        IFS='|' read -r project_id project_name project_path has_git has_makefile has_package_json git_remote <<< "$project_info"
        
        if ! project_exists "$project_id"; then
            local created_id=$(create_project_memory "$project_id" "$project_name" "$project_path" "$has_git" "$has_makefile" "$has_package_json" "$git_remote")
            echo "$created_id"
        else
            info "Project already exists: $project_id"
        fi
        
        # Don't recurse into project directories (they might have nested projects that are submodules)
        return 0
    fi
    
    # Recurse into subdirectories
    local subdirs=()
    while IFS= read -r -d '' dir; do
        subdirs+=("$dir")
    done < <(find "$search_dir" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
    
    for subdir in "${subdirs[@]}"; do
        discover_projects_in_dir "$subdir" $((current_depth + 1))
    done
}

# Main discovery function
main() {
    local action="${1:-discover}"
    local target_dirs=("${@:2}")
    
    if [[ ${#target_dirs[@]} -eq 0 ]]; then
        target_dirs=("${SEARCH_ROOTS[@]}")
    fi
    
    case "$action" in
        "discover")
            info "Starting project discovery..."
            info "Search roots: ${target_dirs[*]}"
            info "Max depth: $MAX_DEPTH"
            
            local created_projects=()
            for search_root in "${target_dirs[@]}"; do
                if [[ -d "$search_root" ]]; then
                    local projects=$(discover_projects_in_dir "$search_root" 1)
                    if [[ -n "$projects" ]]; then
                        while IFS= read -r project_id; do
                            [[ -n "$project_id" ]] && created_projects+=("$project_id")
                        done <<< "$projects"
                    fi
                fi
            done
            
            echo >&2
            if [[ ${#created_projects[@]} -eq 0 ]]; then
                info "No new projects discovered"
            else
                success "Created memory for ${#created_projects[@]} projects:"
                for project_id in "${created_projects[@]}"; do
                    echo "  - $project_id" >&2
                done
            fi
            ;;
            
        "scan")
            # Just scan and report, don't create
            info "Scanning for potential projects..."
            for search_root in "${target_dirs[@]}"; do
                [[ -d "$search_root" ]] && find "$search_root" -maxdepth $MAX_DEPTH -name ".git" -o -name "Makefile" -o -name "package.json" | head -20
            done
            ;;
            
        *)
            echo "Usage: $0 [discover|scan] [directories...]" >&2
            echo "  discover: Find and create memory for new projects (default)" >&2
            echo "  scan: Just scan for potential projects without creating memory" >&2
            exit 1
            ;;
    esac
}

# Entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi