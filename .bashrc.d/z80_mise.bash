# Only activate mise if tools are not already in PATH
# Note: Don't check MISE_SHELL - it's inherited but PATH is rebuilt by 2-path.bash / z70_path.bash
if ! echo "$PATH" | grep -q "mise/installs\|mise/shims"; then
    MISE_PATH="$HOME/.local/bin/mise"
    if [[ -t 0 ]]; then
        # Generate activation live: since mise 2026.10.13 it embeds the current PATH.
        # Caching it would replace the PATH built for this shell with the timer's PATH.
        # A nested shell inherits the parent's mise state, but 2-path.bash rebuilt PATH from
        # scratch, so that state is wrong: hook-env would see "already applied" and add no tools.
        unset __MISE_DIFF __MISE_SESSION __MISE_ORIG_PATH __MISE_WATCH
        eval "$($MISE_PATH activate bash)"
        eval "$($MISE_PATH hook-env -s bash)"
    else
        # Non-interactive: use shims only (already fast)
        eval "$($MISE_PATH activate --shims)"
    fi
fi

# NOTE: FZF_COMPLETION_TRIGGER removed from here (was duplicate)
# Now defined only in 4-fzf.bash for clarity
