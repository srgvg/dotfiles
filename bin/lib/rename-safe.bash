#!/usr/bin/env bash
# Shared by rename2timestamp and rename4space. Callers supply parallel arrays of
# absolute source/destination paths; preflight the entire batch before any writes.

rename_path() {
    local file=$1 parent
    while [[ "$file" == */ && "$file" != / ]]; do
        file=${file%/}
    done
    [[ "$file" == */* ]] || file="./$file"
    # Resolve directory aliases while preserving the final component (a symlink
    # itself is what mv renames). NUL output preserves trailing newlines too.
    parent=${file%/*}
    IFS= read -r -d '' parent < <(realpath -ez -- "${parent:-/}") || return 1
    # Returned to the calling script without a newline-delimited substitution.
    # shellcheck disable=SC2034
    RENAME_PATH="${parent%/}/${file##*/}"
}

rename_batch() {
    local operation=$1 preview=$2 i src dst output
    local -n batch_sources=$3 batch_destinations=$4
    local -A seen=()

    for i in "${!batch_sources[@]}"; do
        src=${batch_sources[$i]}
        dst=${batch_destinations[$i]}
        if [[ -n "${seen[$dst]+present}" ]]; then
            printf 'Duplicate destination: %s\n' "$dst" >&2
            return 1
        fi
        seen["$dst"]=1
        [[ "$src" == "$dst" ]] && continue
        if [[ -e "$dst" || -L "$dst" ]]; then
            printf 'Destination already exists: %s\n' "$dst" >&2
            return 1
        fi
    done

    for i in "${!batch_sources[@]}"; do
        src=${batch_sources[$i]}
        dst=${batch_destinations[$i]}
        [[ "$src" == "$dst" ]] && continue
        if [[ "$preview" == true ]]; then
            printf '%q ' "$operation" --no-clobber --no-target-directory --verbose -- "$src" "$dst"
            printf '\n'
        else
            # GNU cp/mv can exit zero when -n skips a racing destination. Verbose
            # output is nonempty only when an operation actually happened; do not
            # parse its wording or assume a skipped operation was successful.
            output=$("$operation" --no-clobber --no-target-directory --verbose -- "$src" "$dst") || return 1
            if [[ -z "$output" ]]; then
                printf 'Operation skipped; destination may have appeared: %s\n' "$dst" >&2
                return 1
            fi
            printf '%s\n' "$output"
        fi
    done
}
