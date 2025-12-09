#!/usr/bin/env bash
#
# Safe /tmp cleanup script.
#
# Defaults:
#   - Target directory: /tmp
#   - Age threshold:    7 days
#   - Scope:            current user only
#   - Mode:             dry-run (no deletions)

set -euo pipefail

DEFAULT_TARGET="/tmp"
DEFAULT_AGE_DAYS=7

usage() {
  cat <<'EOF'
Usage: clean-tmp.sh [options]

Options:
  --path DIR        Directory to clean (default: /tmp)
  --age DAYS        Only remove entries older than DAYS (default: 7)
  --all             Clean files from all users (default: only current user)
  --no-dry-run      Actually delete files (default: dry-run)
  -h, --help        Show this help

Examples:
  clean-tmp.sh
  clean-tmp.sh --no-dry-run
  clean-tmp.sh --path /var/tmp --age 2 --no-dry-run
  clean-tmp.sh --all --no-dry-run
EOF
}

TARGET="$DEFAULT_TARGET"
AGE_DAYS="$DEFAULT_AGE_DAYS"
ALL_USERS=0
DRY_RUN=1

# --- Parse arguments ---------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)
      [[ $# -ge 2 ]] || { echo "Error: --path requires an argument" >&2; exit 1; }
      TARGET="$2"
      shift 2
      ;;
    --age)
      [[ $# -ge 2 ]] || { echo "Error: --age requires an argument" >&2; exit 1; }
      AGE_DAYS="$2"
      shift 2
      ;;
    --all)
      ALL_USERS=1
      shift
      ;;
    --no-dry-run|--force)
      DRY_RUN=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

# --- Basic validation --------------------------------------------------------
if [[ ! -d "$TARGET" ]]; then
  echo "Error: target '$TARGET' is not a directory" >&2
  exit 1
fi

# Require an absolute path to avoid weirdness with rm / find
if [[ "$TARGET" != /* ]]; then
  echo "Error: target '$TARGET' must be an absolute path" >&2
  exit 1
fi

# Extra paranoia: refuse obviously dangerous targets
case "$TARGET" in
  /|/etc|/var|/home|/usr|/opt|/root|/boot|/bin|/sbin|/lib|/lib64)
    echo "Refusing to operate on extremely sensitive directory: $TARGET" >&2
    exit 1
    ;;
esac

# Age must be a non-negative integer
if ! [[ "$AGE_DAYS" =~ ^[0-9]+$ ]]; then
  echo "Error: age must be a non-negative integer (got '$AGE_DAYS')" >&2
  exit 1
fi

# --- Build find expression ---------------------------------------------------
owner_expr=()
if (( ALL_USERS == 0 )); then
  # Use numeric UID to avoid name lookup issues
  owner_expr=(-user "$(id -u)")
fi

# Common find command (as an array for safety)
# -mindepth 1 -maxdepth 1 : only top-level entries (rm -rf handles recursion)
# -xdev                   : stay on this filesystem
common_find=(find "$TARGET"
  -mindepth 1
  -maxdepth 1
  -xdev
  -not -name 'ssh-*'
  \( -type f -o -type d -o -type l -o -type s -o -type p \)
  -mtime +"$AGE_DAYS"
  "${owner_expr[@]}"
)

# --- Run ---------------------------------------------------------------------
if (( DRY_RUN == 1 )); then
  echo "# Dry run: showing entries that WOULD be deleted from '$TARGET'"
  echo "# Age > $AGE_DAYS day(s), scope: $([[ $ALL_USERS -eq 1 ]] && echo "all users" || echo "current user only")"
  echo

  # shellcheck disable=SC2145
  # Allow non-zero exit from find (permission errors are expected)
  "${common_find[@]}" -print 2>/dev/null || true
else
  echo "# EXECUTION: deleting entries from '$TARGET'"
  echo "# Age > $AGE_DAYS day(s), scope: $([[ $ALL_USERS -eq 1 ]] && echo "all users" || echo "current user only")"
  echo "# Proceeding in 3 seconds. Press Ctrl+C to abort."
  sleep 3

  # Actual deletion using rm -rf (handles nested permission issues)
  "${common_find[@]}" -print0 2>/dev/null | xargs -0 --no-run-if-empty rm -rfv

  echo "# Cleanup completed."
fi

