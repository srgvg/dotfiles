# Only activate mise if tools are not already in PATH
# Note: Don't check MISE_SHELL - it's inherited but PATH is rebuilt by 2-path.bash
if ! echo "$PATH" | grep -q "mise/installs\|mise/shims"; then
    MISE_PATH="$HOME/.local/bin/mise"
    if [[ -t 0 ]]; then
        # Interactive terminal: use pre-generated cache (regenerated hourly via update-tools)
        # To manually regenerate: update-tools shell-init
        _mise_activate="$HOME/.cache/shell-init/mise-activate.bash"
        _mise_hook="$HOME/.cache/shell-init/mise-hook.bash"
        if [[ -f "$_mise_activate" ]] && [[ -f "$_mise_hook" ]]; then
            source "$_mise_activate"
            source "$_mise_hook"
        else
            # Fallback if cache missing (first run)
            eval "$($MISE_PATH activate bash)"
            eval "$($MISE_PATH hook-env)"
        fi
        unset _mise_activate _mise_hook
    else
        # Non-interactive: use shims only (already fast)
        eval "$($MISE_PATH activate --shims)"
    fi
fi

# NOTE: FZF_COMPLETION_TRIGGER removed from here (was duplicate)
# Now defined only in 4-fzf.bash for clarity
