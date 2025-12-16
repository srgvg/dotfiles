# Only activate mise if tools are not already in PATH
# Note: Don't check MISE_SHELL - it's inherited but PATH is rebuilt by 2-path.bash
if ! echo "$PATH" | grep -q "mise/installs\|mise/shims"; then
    if [[ -t 0 ]]; then
        # Interactive terminal: full activation for better performance
        eval "$(/home/serge/bin2/mise activate bash)"
        eval "$(mise hook-env)"
    else
        # Non-interactive: use shims only (faster, less overhead)
        eval "$(mise activate --shims)"
    fi
fi

FZF_COMPLETION_TRIGGER="~~"
