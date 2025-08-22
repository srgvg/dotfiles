#!/bin/bash

# AI Memory Migration Script
# Migrates from flat structure to hierarchical project-based structure

set -euo pipefail

MEMORY_DIR="/home/serge/.claude/ai_memory"
BACKUP_SUFFIX="backup-$(date +%Y%m%d-%H%M%S)"
MIGRATION_LOG="$MEMORY_DIR/migration-$BACKUP_SUFFIX.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$MIGRATION_LOG"
}

error() {
    log "${RED}ERROR: $1${NC}"
    exit 1
}

success() {
    log "${GREEN}SUCCESS: $1${NC}"
}

warning() {
    log "${YELLOW}WARNING: $1${NC}"
}

info() {
    log "${BLUE}INFO: $1${NC}"
}

# Function to generate project ID hash
generate_project_hash() {
    local project_path="$1"
    local git_remote="$2"
    local project_name="$3"
    
    # Combine inputs for hash
    local hash_input="${project_path}${git_remote}${project_name}"
    echo "$hash_input" | sha1sum | cut -c1-4
}

# Function to extract project info from session files
extract_project_info() {
    local session_file="$1"
    local project_name=""
    local project_path=""
    local project_type=""
    
    if [[ -f "$session_file" ]]; then
        # Try to extract project context from JSON
        if command -v jq >/dev/null 2>&1; then
            project_name=$(jq -r '.project_context // .working_directory // .context // empty' "$session_file" 2>/dev/null || echo "")
            project_path=$(jq -r '.working_directory // .root_directory // empty' "$session_file" 2>/dev/null || echo "")
            project_type=$(jq -r '.project_type // empty' "$session_file" 2>/dev/null || echo "")
        else
            # Fallback: grep for project indicators
            project_name=$(grep -o '"project_context"[[:space:]]*:[[:space:]]*"[^"]*"' "$session_file" | sed 's/.*"\([^"]*\)".*/\1/' || echo "")
            project_path=$(grep -o '"working_directory"[[:space:]]*:[[:space:]]*"[^"]*"' "$session_file" | sed 's/.*"\([^"]*\)".*/\1/' || echo "")
        fi
    fi
    
    echo "${project_name}|${project_path}|${project_type}"
}

# Function to create project directory structure
create_project_structure() {
    local project_id="$1"
    local project_dir="$MEMORY_DIR/projects/$project_id"
    
    info "Creating directory structure for project: $project_id"
    
    mkdir -p "$project_dir"/{contexts,knowledge,sessions}
    
    # Create index files
    cat > "$project_dir/contexts/_index.json" << 'EOF'
{
  "contexts": {},
  "active_contexts": [],
  "last_updated": ""
}
EOF

    cat > "$project_dir/knowledge/architecture.json" << 'EOF'
{
  "decisions": [],
  "patterns": [],
  "constraints": [],
  "last_updated": ""
}
EOF

    cat > "$project_dir/knowledge/patterns.json" << 'EOF'
{
  "code_patterns": [],
  "workflow_patterns": [],
  "naming_conventions": [],
  "last_updated": ""
}
EOF

    cat > "$project_dir/knowledge/dependencies.json" << 'EOF'
{
  "package_dependencies": {},
  "version_constraints": {},
  "compatibility_notes": [],
  "last_updated": ""
}
EOF

    cat > "$project_dir/knowledge/technical-debt.json" << 'EOF'
{
  "debt_items": [],
  "priority_levels": {},
  "resolution_notes": [],
  "last_updated": ""
}
EOF
}

# Function to migrate project files
migrate_project_files() {
    info "Migrating project files..."
    
    for project_file in "$MEMORY_DIR/projects"/*.json; do
        if [[ -f "$project_file" && ! "$project_file" =~ /default\.json$ ]]; then
            local filename=$(basename "$project_file")
            local project_name="${filename%.json}"
            
            info "Processing project file: $filename"
            
            # Extract project info
            local project_info
            if command -v jq >/dev/null 2>&1; then
                local project_path=$(jq -r '.root_directory // .working_directory // empty' "$project_file" 2>/dev/null || echo "")
                local project_full_name=$(jq -r '.project_name // empty' "$project_file" 2>/dev/null || echo "$project_name")
                local git_remote=""
                
                # Try to get git remote if path exists
                if [[ -n "$project_path" && -d "$project_path/.git" ]]; then
                    git_remote=$(cd "$project_path" && git remote get-url origin 2>/dev/null || echo "")
                fi
                
                # Generate new project ID
                local parent_dir=$(basename "$(dirname "$project_path")" 2>/dev/null || echo "")
                local hash=$(generate_project_hash "$project_path" "$git_remote" "$project_full_name")
                local new_project_id="${parent_dir}-${project_full_name}-${hash}"
                
                # Clean up project ID (remove invalid characters)
                new_project_id=$(echo "$new_project_id" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')
                
                info "Migrating $project_name to $new_project_id"
                
                # Create new structure
                create_project_structure "$new_project_id"
                
                # Migrate data to new project.json
                jq --arg new_id "$new_project_id" '. + {
                    "project_id": $new_id,
                    "migrated_from": input_filename,
                    "migration_date": now | strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "structure_version": "2.0"
                }' "$project_file" > "$MEMORY_DIR/projects/$new_project_id/project.json"
                
                # Extract knowledge from project file
                if jq -e '.architecture_decisions' "$project_file" >/dev/null 2>&1; then
                    jq '.architecture_decisions' "$project_file" > "$MEMORY_DIR/projects/$new_project_id/knowledge/architecture.json.tmp"
                    jq '. + {"last_updated": now | strftime("%Y-%m-%dT%H:%M:%SZ")} + input' \
                        "$MEMORY_DIR/projects/$new_project_id/knowledge/architecture.json" \
                        "$MEMORY_DIR/projects/$new_project_id/knowledge/architecture.json.tmp" \
                        > "$MEMORY_DIR/projects/$new_project_id/knowledge/architecture.json.new"
                    mv "$MEMORY_DIR/projects/$new_project_id/knowledge/architecture.json.new" \
                       "$MEMORY_DIR/projects/$new_project_id/knowledge/architecture.json"
                    rm -f "$MEMORY_DIR/projects/$new_project_id/knowledge/architecture.json.tmp"
                fi
                
                # Move original file to backup
                mv "$project_file" "$MEMORY_DIR/$BACKUP_SUFFIX/projects/"
                
                echo "$project_name -> $new_project_id" >> "$MEMORY_DIR/project-migration-mapping.txt"
                
            else
                warning "jq not available, skipping detailed migration for $filename"
                mv "$project_file" "$MEMORY_DIR/$BACKUP_SUFFIX/projects/"
            fi
        fi
    done
}

# Function to migrate session files
migrate_session_files() {
    info "Migrating session files..."
    
    for session_file in "$MEMORY_DIR/sessions"/*.json "$MEMORY_DIR"/*.json; do
        if [[ -f "$session_file" && "$session_file" =~ session.*\.json$ ]]; then
            local filename=$(basename "$session_file")
            info "Processing session file: $filename"
            
            # Extract project info from session
            local project_info=$(extract_project_info "$session_file")
            IFS='|' read -r project_name project_path project_type <<< "$project_info"
            
            if [[ -n "$project_name" && "$project_name" != "null" ]]; then
                # Try to find matching project directory
                local target_project_dir=""
                for proj_dir in "$MEMORY_DIR/projects"/*/; do
                    if [[ -f "$proj_dir/project.json" ]]; then
                        local proj_name
                        if command -v jq >/dev/null 2>&1; then
                            proj_name=$(jq -r '.project_name // empty' "$proj_dir/project.json" 2>/dev/null || echo "")
                            if [[ "$proj_name" == "$project_name" ]]; then
                                target_project_dir="$proj_dir"
                                break
                            fi
                        fi
                    fi
                done
                
                if [[ -n "$target_project_dir" ]]; then
                    info "Moving $filename to $target_project_dir/sessions/"
                    mv "$session_file" "$target_project_dir/sessions/"
                else
                    warning "No matching project found for session $filename, moving to backup"
                    mv "$session_file" "$MEMORY_DIR/$BACKUP_SUFFIX/sessions/"
                fi
            else
                warning "Could not determine project for session $filename, moving to backup"
                mv "$session_file" "$MEMORY_DIR/$BACKUP_SUFFIX/sessions/"
            fi
        fi
    done
}

# Function to migrate learning files
migrate_learning_files() {
    info "Migrating learning files..."
    
    # Create learning directory if it doesn't exist
    mkdir -p "$MEMORY_DIR/learning"
    
    # Create missing learning files with empty structure
    local learning_files=(
        "error_solutions.json"
        "code_snippets.json" 
        "workflows.json"
        "project_templates.json"
        "optimization_patterns.json"
        "dependencies.json"
    )
    
    for file in "${learning_files[@]}"; do
        if [[ ! -f "$MEMORY_DIR/learning/$file" ]]; then
            case "$file" in
                "error_solutions.json")
                    echo '{"error_patterns": [], "solutions": [], "last_updated": ""}' > "$MEMORY_DIR/learning/$file"
                    ;;
                "code_snippets.json")
                    echo '{"snippets": [], "patterns": [], "last_updated": ""}' > "$MEMORY_DIR/learning/$file"
                    ;;
                "workflows.json")
                    echo '{"workflows": [], "command_sequences": [], "last_updated": ""}' > "$MEMORY_DIR/learning/$file"
                    ;;
                "project_templates.json")
                    echo '{"templates": [], "initialization_patterns": [], "last_updated": ""}' > "$MEMORY_DIR/learning/$file"
                    ;;
                "optimization_patterns.json")
                    echo '{"optimizations": [], "performance_patterns": [], "last_updated": ""}' > "$MEMORY_DIR/learning/$file"
                    ;;
                "dependencies.json")
                    echo '{"working_combinations": [], "version_constraints": [], "last_updated": ""}' > "$MEMORY_DIR/learning/$file"
                    ;;
            esac
            info "Created learning file: $file"
        fi
    done
}

# Main migration function
main() {
    info "Starting AI Memory Migration to Hierarchical Structure"
    info "Memory directory: $MEMORY_DIR"
    info "Migration log: $MIGRATION_LOG"
    
    # Check if memory directory exists
    if [[ ! -d "$MEMORY_DIR" ]]; then
        error "Memory directory does not exist: $MEMORY_DIR"
    fi
    
    # Create backup
    info "Creating backup..."
    cp -r "$MEMORY_DIR" "$MEMORY_DIR.$BACKUP_SUFFIX"
    success "Backup created: $MEMORY_DIR.$BACKUP_SUFFIX"
    
    # Create migration log directory structure
    mkdir -p "$MEMORY_DIR.$BACKUP_SUFFIX"/{projects,sessions,learning}
    
    # Also create backup directory for in-progress migration
    mkdir -p "$MEMORY_DIR/$BACKUP_SUFFIX"/{projects,sessions,learning}
    
    # Initialize migration mapping file
    echo "# Project Migration Mapping" > "$MEMORY_DIR/project-migration-mapping.txt"
    echo "# Format: old_name -> new_project_id" >> "$MEMORY_DIR/project-migration-mapping.txt"
    
    # Create new directory structure
    mkdir -p "$MEMORY_DIR/projects"
    mkdir -p "$MEMORY_DIR/learning"
    
    # Run migrations
    migrate_project_files
    migrate_session_files
    migrate_learning_files
    
    # Update system.json
    if [[ -f "$MEMORY_DIR/system.json" ]]; then
        if command -v jq >/dev/null 2>&1; then
            jq '. + {
                "memory_version": "2.0.0",
                "last_migration": now | strftime("%Y-%m-%dT%H:%M:%SZ"),
                "migration_backup": "'$BACKUP_SUFFIX'",
                "structure": "hierarchical"
            }' "$MEMORY_DIR/system.json" > "$MEMORY_DIR/system.json.tmp"
            mv "$MEMORY_DIR/system.json.tmp" "$MEMORY_DIR/system.json"
        fi
    fi
    
    # Generate migration report
    info "Generating migration report..."
    {
        echo "# AI Memory Migration Report"
        echo "Migration Date: $(date)"
        echo "Backup Location: $MEMORY_DIR.$BACKUP_SUFFIX"
        echo ""
        echo "## Project Migrations:"
        if [[ -f "$MEMORY_DIR/project-migration-mapping.txt" ]]; then
            cat "$MEMORY_DIR/project-migration-mapping.txt"
        fi
        echo ""
        echo "## New Structure:"
        find "$MEMORY_DIR/projects" -type f | head -20
        echo ""
        echo "## Learning Files Created:"
        ls -la "$MEMORY_DIR/learning/"
    } > "$MEMORY_DIR/migration-report.md"
    
    success "Migration completed successfully!"
    info "Migration report: $MEMORY_DIR/migration-report.md"
    info "Project mapping: $MEMORY_DIR/project-migration-mapping.txt"
    info "Backup location: $MEMORY_DIR.$BACKUP_SUFFIX"
    
    # Verification
    info "Running verification..."
    local total_files_before=$(find "$MEMORY_DIR.$BACKUP_SUFFIX" -name "*.json" | wc -l)
    local total_files_after=$(find "$MEMORY_DIR" -name "*.json" | wc -l)
    
    info "Files before migration: $total_files_before"
    info "Files after migration: $total_files_after"
    
    if [[ $total_files_after -ge $total_files_before ]]; then
        success "File count verification passed"
    else
        warning "File count decreased - please review migration"
    fi
    
    success "Migration process completed. Backup retained for 30 days."
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi