#!/usr/bin/env bash

# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t
# vi: set shiftwidth=4 tabstop=4 noexpandtab:
# :indentSize=4:tabSize=4:noTabs=false:

set -o nounset
set -o errexit
set -o pipefail

###############################################################################
# Run shellcheck on all shell scripts in ~/bin directories
###############################################################################

# Default settings
SEVERITY="${SHELLCHECK_SEVERITY:-style}"
FORMAT="${SHELLCHECK_FORMAT:-tty}"
DIRS=("$HOME/bin" "$HOME/bin2" "$HOME/bins")
VERBOSE=0
COUNT_ONLY=0

usage() {
	cat <<-'EOF'
	Usage: shellcheck-all.sh [OPTIONS]

	Run shellcheck on all shell scripts in ~/bin, ~/bin2, and ~/bins

	Options:
	  -s, --severity LEVEL  Minimum severity: error, warning, info, style (default: style)
	  -f, --format FORMAT   Output format: tty, gcc, json, checkstyle (default: tty)
	  -c, --count           Only show count of issues by severity
	  -v, --verbose         Show which files are being checked
	  -h, --help            Show this help message

	Environment variables:
	  SHELLCHECK_SEVERITY   Default severity level
	  SHELLCHECK_FORMAT     Default output format

	Examples:
	  shellcheck-all.sh                    # Check all with default settings
	  shellcheck-all.sh -s error           # Only show errors
	  shellcheck-all.sh -s warning -c      # Count warnings and errors
	  shellcheck-all.sh -f gcc             # Output in gcc format for editors
	EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
	case $1 in
		-s|--severity)
			SEVERITY="$2"
			shift 2
			;;
		-f|--format)
			FORMAT="$2"
			shift 2
			;;
		-c|--count)
			COUNT_ONLY=1
			shift
			;;
		-v|--verbose)
			VERBOSE=1
			shift
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			echo "Unknown option: $1" >&2
			usage >&2
			exit 1
			;;
	esac
done

# Validate severity
case $SEVERITY in
	error|warning|info|style) ;;
	*)
		echo "Invalid severity: $SEVERITY" >&2
		echo "Valid values: error, warning, info, style" >&2
		exit 1
		;;
esac

# Find all shell scripts by checking shebang
find_shell_scripts() {
	local dir="$1"
	[[ -d "$dir" ]] || return 0

	while IFS= read -r -d '' file; do
		# Skip non-regular files
		[[ -f "$file" ]] || continue
		# Check if file starts with shell shebang
		if head -1 "$file" 2>/dev/null | grep -qE '^#!.*(bash|sh)'; then
			echo "$file"
		fi
	done < <(find "$dir" -maxdepth 1 -type f -print0 2>/dev/null)
}

# Collect all shell scripts
scripts=()
for dir in "${DIRS[@]}"; do
	while IFS= read -r script; do
		[[ -n "$script" ]] && scripts+=("$script")
	done < <(find_shell_scripts "$dir")
done

if [[ ${#scripts[@]} -eq 0 ]]; then
	echo "No shell scripts found" >&2
	exit 0
fi

[[ $VERBOSE -eq 1 ]] && echo "Found ${#scripts[@]} shell scripts to check" >&2

# Run shellcheck
if [[ $COUNT_ONLY -eq 1 ]]; then
	# Count issues by severity
	output=$(shellcheck --format=gcc --severity="$SEVERITY" "${scripts[@]}" 2>/dev/null || true)

	errors=$(echo "$output" | grep -c ": error:" || true)
	warnings=$(echo "$output" | grep -c ": warning:" || true)
	notes=$(echo "$output" | grep -c ": note:" || true)
	total=$((errors + warnings + notes))

	echo "ShellCheck Summary (${#scripts[@]} scripts)"
	echo "================================"
	echo "Errors:   $errors"
	echo "Warnings: $warnings"
	echo "Notes:    $notes"
	echo "--------------------------------"
	echo "Total:    $total"

	[[ $errors -gt 0 ]] && exit 1
	exit 0
else
	# Run shellcheck with specified format
	if [[ $VERBOSE -eq 1 ]]; then
		for script in "${scripts[@]}"; do
			echo "Checking: $script" >&2
		done
	fi

	# SC returns non-zero if issues found, which is expected
	shellcheck --format="$FORMAT" --severity="$SEVERITY" "${scripts[@]}" || true
fi
