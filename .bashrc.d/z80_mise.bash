# Only activate mise if tools are not already in PATH
# Note: Don't check MISE_SHELL - it's inherited but PATH is rebuilt by 2-path.bash / z70_path.bash
if ! echo "$PATH" | grep -q "mise/installs\|mise/shims"; then
    MISE_PATH="$HOME/.local/bin/mise"
    if [[ -t 0 ]]; then
        # Interactive terminal: the activate script is static, so it is pre-generated
        # (every 4h by update-tools; manually: update-tools shell-init).
        # hook-env is NOT cached: its output hard-codes the full PATH of whatever process
        # generated it, which silently replaced the order built by 2-path.bash (2026-09-23).
        # A nested shell inherits the parent's mise state, but 2-path.bash rebuilt PATH from
        # scratch, so that state is wrong: hook-env would see "already applied" and add no tools.
        unset __MISE_DIFF __MISE_SESSION __MISE_ORIG_PATH __MISE_WATCH
        _mise_activate="$HOME/.cache/shell-init/mise-activate.bash"
        if [[ -f "$_mise_activate" ]]; then
            # shellcheck source=/dev/null
            source "$_mise_activate"
        else
            # Fallback if cache missing (first run)
            eval "$($MISE_PATH activate bash)"
        fi
        eval "$($MISE_PATH hook-env -s bash)"
        unset _mise_activate
    else
        # Non-interactive: use shims only (already fast)
        eval "$($MISE_PATH activate --shims)"
    fi
fi

# NOTE: FZF_COMPLETION_TRIGGER removed from here (was duplicate)
# Now defined only in 4-fzf.bash for clarity
