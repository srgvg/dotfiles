pathmunge $HOME/.atuin/bin/ before
source "$HOME/.atuin/bin/env"

# bash-preexec is required by atuin
[[ -f ~/.bash-preexec.sh ]] && source ~/.bash-preexec.sh

# https://docs.atuin.sh/configuration/key-binding/#bash
export ATUIN_NOBIND="true"

# Use pre-generated cache (regenerated hourly via update-tools)
# To manually regenerate: update-tools shell-init
_atuin_cache="$HOME/.cache/shell-init/atuin.bash"
if [[ -f "$_atuin_cache" ]]; then
    source "$_atuin_cache"
else
    # Fallback if cache missing (first run)
    eval "$(atuin init bash)"
fi
unset _atuin_cache

# bind to ctrl-r, add any other bindings you want here too
# Only set up bindings in interactive shells
if [[ $- == *i* ]]; then
    bind -x '"\C-r": __atuin_history'
fi

# bind to the up key, which depends on terminal mode
#bind -x '"\e[A": __atuin_history --shell-up-key-binding'
#bind -x '"\eOA": __atuin_history --shell-up-key-binding'
