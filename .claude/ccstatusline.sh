#!/usr/bin/env bash

#============================================================================
# ClaudeCode Status Line Script (ccstatusline.sh)
# Version: 1.0.1
# Author: DKMaker with great help from Claude Code
# License: MIT
#
# Description:
#   Displays a formatted status line for Claude Code with model info,
#   version, update notifications, and current directory context.
#
# Features:
#   - Shows current AI model and version
#   - Auto-checks for updates hourly (non-blocking)
#   - Color-coded directory indicators
#   - Three-level logging system (error/info/debug)
#   - Debug mode for troubleshooting
#   - Graceful error handling for Claude Code integration
#
# Usage:
#   Normal:  echo "$json_data" | bash statusline.sh
#   Debug:   echo "$json_data" | bash statusline.sh --debug
#   Logging: echo "$json_data" | bash statusline.sh --loglevel debug
#
# Format:
#   🤖 Model * Version [🔄 NewVersion] 📂 Path
#============================================================================

# Modified safety flags for Claude Code integration
# We avoid strict error handling to ensure the script always outputs something
# set -o pipefail  # Disabled - can cause silent failures with pipes
IFS=$'\n\t'

# Bash version check - warn but don't exit
if [[ "${BASH_VERSION%%.*}" -lt 4 ]]; then
    # Output a fallback statusline and continue
    echo "Claude Code (Bash < 4.0)"
    exit 0
fi

#============================================================================
# GLOBAL VARIABLES
#============================================================================

# Script metadata
readonly SCRIPT_VERSION="1.0.1"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse command line arguments
LOG_LEVEL="error"  # Default log level
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug|-d)
            LOG_LEVEL="info"  # Backward compatibility
            shift
            ;;
        --loglevel)
            if [[ -n "$2" ]]; then
                case "$2" in
                    error|info|debug)
                        LOG_LEVEL="$2"
                        ;;
                    *)
                        LOG_LEVEL="error"
                        ;;
                esac
                shift 2
            else
                LOG_LEVEL="error"
                shift
            fi
            ;;
        --loglevel=*)
            LOG_LEVEL="${1#--loglevel=}"
            case "$LOG_LEVEL" in
                error|info|debug)
                    ;;  # Valid log level
                *)
                    LOG_LEVEL="error"
                    ;;
            esac
            shift
            ;;
        *)
            # Unknown argument, skip it
            shift
            ;;
    esac
done

# Paths (with safe defaults)
readonly CLAUDE_DIR="${HOME:-/tmp}/.claude"
readonly VERSION_CACHE_FILE="${CLAUDE_DIR}/latest_version_check"
readonly LOCKFILE="${VERSION_CACHE_FILE}.lock"
readonly PID_FILE="${VERSION_CACHE_FILE}.pid"
readonly LOG_FILE="${CLAUDE_DIR}/statusline.log"
readonly NPM_PACKAGE="@anthropic-ai/claude-code"
readonly CACHE_DURATION_MINUTES=60
readonly MAX_LOG_SIZE=1048576  # 1MB

# Check for NO_COLOR environment variable
# Note: We don't check terminal (! -t 1) since statusline is always piped
if [[ -n "${NO_COLOR:-}" ]]; then
    readonly USE_COLOR=false
else
    readonly USE_COLOR=true
fi

# Define colors conditionally
if [[ "$USE_COLOR" == true ]]; then
    readonly COLOR_CYAN="\033[96m"
    readonly COLOR_GREEN="\033[92m"
    readonly COLOR_RED="\033[91m"
    readonly COLOR_ORANGE="\033[38;5;208m"
    readonly COLOR_BLUE="\033[94m"
    readonly COLOR_YELLOW="\033[93m"
    readonly COLOR_RESET="\033[0m"
    readonly COLOR_ASTERISK_BG="\033[48;2;218;115;88m\033[97m"
else
    readonly COLOR_CYAN=""
    readonly COLOR_GREEN=""
    readonly COLOR_RED=""
    readonly COLOR_ORANGE=""
    readonly COLOR_BLUE=""
    readonly COLOR_YELLOW=""
    readonly COLOR_RESET=""
    readonly COLOR_ASTERISK_BG=""
fi

# Icons
readonly ICON_MODEL="🤖"
readonly ICON_FOLDER_ROOT="📁"
readonly ICON_FOLDER_SUB="📂"
readonly ICON_UPDATE="🔄"
readonly ICON_LOG_INFO="ℹ️"
readonly ICON_LOG_DEBUG="🐛"

# Platform detection
readonly OS_TYPE="$(uname -s)"

#============================================================================
# CLEANUP & ERROR HANDLING
#============================================================================

# Cleanup function
cleanup() {
    local exit_code=$?

    # Clean up PID file but DON'T kill the background version check process
    # We want it to continue running after the script exits to update the cache
    if [[ -f "$PID_FILE" ]]; then
        rm -f "$PID_FILE" 2>/dev/null || true
    fi

    # Remove lockfile if we own it
    if [[ -d "$LOCKFILE" ]]; then
        rmdir "$LOCKFILE" 2>/dev/null || true
    fi

    # Always exit with 0 for Claude Code integration
    exit 0
}
trap cleanup EXIT INT TERM

# Error function - now outputs a fallback statusline instead of exiting
error() {
    local msg="$1"
    log_error "$msg"

    # Output a minimal fallback statusline
    echo "Claude Code (Error: $msg)"

    # Always exit successfully for Claude Code
    exit 0
}

# Logging functions
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    # Determine if we should log based on current log level
    local should_log=false
    case "$LOG_LEVEL" in
        "error")
            [[ "$level" == "ERROR" ]] && should_log=true
            ;;
        "info")
            [[ "$level" == "ERROR" || "$level" == "INFO" ]] && should_log=true
            ;;
        "debug")
            should_log=true
            ;;
    esac

    if [[ "$should_log" == true ]]; then
        # Output to stderr for visibility
        echo "[$level] $message" >&2

        # Create .claude directory if it doesn't exist
        [[ ! -d "$CLAUDE_DIR" ]] && mkdir -p "$CLAUDE_DIR" 2>/dev/null || true

        # Rotate log if too large
        if [[ -f "$LOG_FILE" ]] && [[ $(get_file_size "$LOG_FILE") -gt $MAX_LOG_SIZE ]]; then
            mv "$LOG_FILE" "${LOG_FILE}.old" 2>/dev/null || true
        fi

        # Log to file with timestamp
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# Convenience functions for different log levels
log_error() {
    log_message "ERROR" "$1"
}

log_info() {
    log_message "INFO" "$1"
}

log_debug() {
    log_message "DEBUG" "$1"
}

# Legacy debug function for backward compatibility
debug() {
    log_info "$1"
}

#============================================================================
# UTILITY FUNCTIONS
#============================================================================

# Function: Get file size (cross-platform)
get_file_size() {
    local file="$1"
    if [[ "$OS_TYPE" == "Darwin" ]]; then
        stat -f %z "$file" 2>/dev/null || echo 0
    else
        stat -c %s "$file" 2>/dev/null || echo 0
    fi
}

# Function: Get file modification time (cross-platform)
get_file_mtime() {
    local file="$1"
    if [[ "$OS_TYPE" == "Darwin" ]]; then
        stat -f %m "$file" 2>/dev/null || echo 0
    else
        stat -c %Y "$file" 2>/dev/null || echo 0
    fi
}

# Function: Check dependencies
check_dependencies() {
    # Only check for npm, and only warn if missing
    if ! command -v npm >/dev/null 2>&1; then
        log_info "npm not found - version checking disabled"
        return 1  # Return failure but don't cause script to exit
    fi

    log_info "All dependencies satisfied"
    return 0
}

# Function: Parse JSON value using pure bash (secure, no subprocess)
parse_json_value() {
    local json="$1"
    local key="$2"

    # Remove newlines and extra whitespace
    json="${json//[$'\n\r\t']/}"

    # Build regex pattern for the key
    local pattern="\"${key}\"[[:space:]]*:[[:space:]]*\"([^\"]*)\""

    if [[ $json =~ $pattern ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
        return 0
    fi

    return 1
}

# Function: Get relative path (cross-platform)
get_relative_path() {
    local target="$1"
    local base="$2"

    # Try realpath first
    if command -v realpath >/dev/null 2>&1; then
        realpath --relative-to="$base" "$target" 2>/dev/null && return 0
    fi

    # Try python as fallback
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import os.path; print(os.path.relpath('$target', '$base'))" 2>/dev/null && return 0
    elif command -v python >/dev/null 2>&1; then
        python -c "import os.path; print(os.path.relpath('$target', '$base'))" 2>/dev/null && return 0
    fi

    # Last resort: just use basename
    basename "$target"
}

#============================================================================
# VERSION CHECK FUNCTIONS
#============================================================================

# Function: Check if version cache needs update
needs_version_check() {
    local cache_file="$1"

    # File doesn't exist
    if [[ ! -f "$cache_file" ]]; then
        log_info "Version cache file doesn't exist"
        return 0
    fi

    # Check if file is older than cache duration
    local file_mtime current_time age_minutes
    file_mtime=$(get_file_mtime "$cache_file")
    current_time=$(date +%s)
    age_minutes=$(( (current_time - file_mtime) / 60 ))

    if [[ $age_minutes -gt $CACHE_DURATION_MINUTES ]]; then
        log_info "Version cache is $age_minutes minutes old (> $CACHE_DURATION_MINUTES)"
        return 0
    fi

    log_info "Version cache is fresh ($age_minutes minutes old)"
    return 1
}

# Function: Validate version format
validate_version() {
    local version="$1"
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?$ ]]
}

# Function: Compare semantic versions
# Returns: 0 if v1 < v2, 1 if v1 = v2, 2 if v1 > v2
compare_versions() {
    local v1="$1"
    local v2="$2"

    # Remove any pre-release tags for comparison (e.g., -beta, -rc1)
    local v1_base="${v1%%-*}"
    local v2_base="${v2%%-*}"

    # Split versions into components
    IFS='.' read -r -a v1_parts <<< "$v1_base"
    IFS='.' read -r -a v2_parts <<< "$v2_base"

    # Compare major, minor, patch
    for i in 0 1 2; do
        local p1="${v1_parts[i]:-0}"
        local p2="${v2_parts[i]:-0}"

        if (( p1 < p2 )); then
            return 0  # v1 < v2
        elif (( p1 > p2 )); then
            return 2  # v1 > v2
        fi
    done

    # If base versions are equal, check pre-release tags
    # No pre-release is considered newer than pre-release
    if [[ "$v1" == *"-"* ]] && [[ "$v2" != *"-"* ]]; then
        return 0  # v1 has pre-release, v2 doesn't - v2 is newer
    elif [[ "$v1" != *"-"* ]] && [[ "$v2" == *"-"* ]]; then
        return 2  # v1 has no pre-release, v2 does - v1 is newer
    fi

    return 1  # versions are equal
}

# Function: Version check with smart sync/async behavior
# Runs synchronously on first execution (no cache file), async on subsequent runs
check_for_updates() {
    local cache_file="$1"

    # Dependencies should already be checked by caller
    # Try to acquire lock (non-blocking)
    if ! mkdir "$LOCKFILE" 2>/dev/null; then
        log_info "Update check already in progress"
        return 1
    fi

    if needs_version_check "$cache_file"; then
        # Determine if this is first run (no cache file exists)
        local is_first_run=false
        if [[ ! -f "$cache_file" ]]; then
            is_first_run=true
            log_info "First run detected - running version check synchronously"
        else
            log_info "Cache exists but stale - running version check in background"
        fi

        # Define the version check logic as a function to avoid duplication
        run_version_check() {
            # Ensure cleanup on exit
            local cleanup_performed=false
            cleanup_version_check() {
                if [[ "$cleanup_performed" == false ]]; then
                    cleanup_performed=true
                    rmdir "$LOCKFILE" 2>/dev/null || true
                    log_debug "Version check cleanup completed"
                fi
            }
            trap cleanup_version_check EXIT

            log_info "Starting npm version check for $NPM_PACKAGE"
            local latest

            # Ensure .claude directory exists before attempting to write cache
            if [[ ! -d "$CLAUDE_DIR" ]]; then
                mkdir -p "$CLAUDE_DIR" 2>/dev/null || {
                    log_error "Cannot create .claude directory: $CLAUDE_DIR"
                    return 1
                }
            fi

            # Use timeout if available to prevent hanging (15 seconds for npm operations)
            if command -v timeout >/dev/null 2>&1; then
                log_debug "Using timeout for npm command (15s timeout)"
                latest=$(timeout 15 npm view "$NPM_PACKAGE" version 2>/dev/null) || {
                    local exit_code=$?
                    if [[ $exit_code -eq 124 ]]; then
                        log_info "npm command timed out after 15 seconds"
                    else
                        log_info "npm command failed with exit code: $exit_code"
                    fi
                    return 1
                }
            else
                log_debug "Running npm command without timeout"
                latest=$(npm view "$NPM_PACKAGE" version 2>/dev/null) || {
                    log_info "npm command failed"
                    return 1
                }
            fi

            # Validate and save version
            if [[ -n "$latest" ]] && validate_version "$latest"; then
                # Atomic write with better error handling
                local temp_file="${cache_file}.tmp.$$"
                if echo "$latest" > "$temp_file" 2>/dev/null && mv "$temp_file" "$cache_file" 2>/dev/null; then
                    log_info "Updated version cache: $latest"
                    return 0
                else
                    log_error "Failed to write version cache file"
                    rm -f "$temp_file" 2>/dev/null || true
                    return 1
                fi
            else
                log_info "Failed to fetch valid version from npm (got: '${latest:-empty}')"
                return 1
            fi
        }

        if [[ "$is_first_run" == true ]]; then
            # Run synchronously on first run to ensure cache is created before script exits
            log_info "First run: executing version check synchronously"
            if run_version_check; then
                log_info "First run version check completed successfully"
            else
                log_info "First run version check failed, but continuing"
            fi
        else
            # Run in background for subsequent runs to avoid blocking
            log_info "Subsequent run: executing version check in background"
            (
                # Add small delay to ensure parent script has time to output statusline
                sleep 0.1 2>/dev/null || true
                if run_version_check; then
                    log_debug "Background version check completed successfully"
                else
                    log_debug "Background version check failed"
                fi
            ) &

            # Store PID for potential cleanup
            local bg_pid=$!
            echo "$bg_pid" > "$PID_FILE" 2>/dev/null || true
            log_debug "Background version check started with PID: $bg_pid"
        fi
    else
        # Not time for update, remove lock
        rmdir "$LOCKFILE" 2>/dev/null || true
    fi
}

# Function: Get latest version if update available
get_latest_version() {
    local current_version="$1"
    local cache_file="$2"

    if [[ -f "$cache_file" ]]; then
        local latest_version
        latest_version=$(<"$cache_file")

        if [[ -n "$latest_version" ]] && [[ "$latest_version" != "$current_version" ]]; then
            # Compare versions to ensure latest is actually newer
            if compare_versions "$current_version" "$latest_version"; then
                # current_version < latest_version (update available)
                echo "$latest_version"
                log_info "Update available: $current_version -> $latest_version"
                return 0
            elif compare_versions "$latest_version" "$current_version"; then
                # latest_version < current_version (user has newer version)
                log_info "Current version ($current_version) is newer than npm version ($latest_version)"
            else
                # versions are equal
                log_info "Versions are equal: $current_version = $latest_version"
            fi
        fi
    fi

    return 1
}

#============================================================================
# PATH FUNCTIONS
#============================================================================

# Function: Determine path display and colors
get_path_info() {
    local current_dir="$1"
    local project_dir="$2"
    local project_name="$(basename ${project_dir})"

    if [[ "$current_dir" == "$project_dir" ]]; then
        # At project root
        echo "${COLOR_GREEN}|${ICON_FOLDER_ROOT}|${project_name} root"
    else
        # In subdirectory - calculate relative path
        local rel_path
        rel_path=$(get_relative_path "$current_dir" "$project_dir")
        echo "${COLOR_RED}|${ICON_FOLDER_SUB}|${rel_path}"
    fi
}

#============================================================================
# MAIN SCRIPT
#============================================================================

main() {
    # Try to read JSON input from stdin with timeout to prevent hanging
    local input=""

    # Read from stdin with a timeout to prevent hanging
    # Use a subshell with timeout if available, otherwise read with a short timeout
    if command -v timeout >/dev/null 2>&1; then
        input=$(timeout 0.5 cat 2>/dev/null) || true
    else
        # Read with built-in timeout (may not work in all shells)
        while IFS= read -t 0.1 -r line 2>/dev/null; do
            input="${input}${line}"
        done || true
    fi

    log_info "Input length: ${#input}"

    # Log raw JSON input at debug level only
    if [[ "$LOG_LEVEL" == "debug" ]]; then
        log_debug "Raw JSON input: $input"
    fi

    # If no input or empty, output a fallback statusline
    if [[ -z "$input" ]]; then
        echo "Claude Code"
        exit 0
    fi

    # Parse JSON values using secure method with defaults
    local current_dir project_dir model version
    current_dir=$(parse_json_value "$input" "current_dir") || current_dir=""
    project_dir=$(parse_json_value "$input" "project_dir") || project_dir=""
    model=$(parse_json_value "$input" "display_name") || model="Claude"
    version=$(parse_json_value "$input" "version") || version=""

    log_info "Parsed values:"
    log_info "  current_dir: $current_dir"
    log_info "  project_dir: $project_dir"
    log_info "  model: $model"
    log_info "  version: $version"

    # If critical fields are missing, output a minimal statusline
    if [[ -z "$current_dir" ]] || [[ -z "$project_dir" ]]; then
        # Still try to show model and version if available
        if [[ -n "$version" ]]; then
            echo "${ICON_MODEL} ${model} * ${version}"
        else
            echo "${ICON_MODEL} ${model}"
        fi
        exit 0
    fi

    # Set version fallback
    if [[ -z "$version" ]]; then
        version="unknown"
        log_info "Version not found, using fallback: $version"
    fi

    # Check for updates with proper error handling
    # First run (no cache): run synchronously to ensure completion
    # Subsequent runs: run in background for non-blocking behavior
    if check_dependencies 2>/dev/null; then
        # Only proceed with version check if dependencies are available
        if needs_version_check "$VERSION_CACHE_FILE"; then
            log_info "Version check needed, initiating update check"
            check_for_updates "$VERSION_CACHE_FILE"
        else
            log_info "Version cache is fresh, skipping update check"
        fi
    else
        log_info "Dependencies not available, skipping version check"
    fi

    # Get latest version if available
    local latest_version=""
    if [[ -f "$VERSION_CACHE_FILE" ]]; then
        latest_version=$(get_latest_version "$version" "$VERSION_CACHE_FILE") || latest_version=""
    fi

    # Get path information (returns: color|icon|text)
    local path_info folder_color folder_icon path_text
    path_info=$(get_path_info "$current_dir" "$project_dir") || path_info="${COLOR_RED}|${ICON_FOLDER_SUB}|$(basename "$current_dir")"

    # Save and restore IFS
    local OLD_IFS="$IFS"
    IFS='|' read -r folder_color folder_icon path_text <<< "$path_info"
    IFS="$OLD_IFS"

    # Build status line components with version color based on update status
    local version_color update_indicator
    if [[ -n "$latest_version" ]]; then
        # Update available: orange for current version, green for new version
        version_color="${COLOR_ORANGE}"
        update_indicator=" ${ICON_UPDATE} ${COLOR_GREEN}${latest_version}"
    else
        # No update: green for current version
        version_color="${COLOR_GREEN}"
        update_indicator=""
    fi

    # Add debug indicator at the beginning if in debug mode
    if [[ "$LOG_LEVEL" == "debug" ]]; then
        printf "%b%s DEBUG%b " "${COLOR_YELLOW}" "${ICON_LOG_DEBUG}" "${COLOR_RESET}"
    fi

    # Output the status line with proper ANSI escape sequences
    printf "%b%s %s%b " "${COLOR_CYAN}" "${ICON_MODEL}" "${model}" "${COLOR_RESET}"
    printf "%b * %b " "${COLOR_ASTERISK_BG}" "${COLOR_RESET}"
    printf "%b%s%b" "${version_color}" "${version}" "${COLOR_RESET}"

    if [[ -n "$update_indicator" ]]; then
        printf " %s %b%s%b" "${ICON_UPDATE}" "${COLOR_GREEN}" "${latest_version}" "${COLOR_RESET}"
    fi

    printf " %b%s %s%b" "${folder_color}" "${folder_icon}" "${path_text}" "${COLOR_RESET}"

    log_info "Status line generated successfully"
}

# Run main function with error protection
# The script is designed to always output something and exit 0
# Wrap in error handling to ensure we always output something
if ! main 2>/dev/null; then
    # If main fails for any reason, output a fallback
    echo "Claude Code"
fi

# Always exit successfully
exit 0
