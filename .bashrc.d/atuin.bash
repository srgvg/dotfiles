pathmunge $HOME/.atuin/bin/ before
source "$HOME/.atuin/bin/env"

# https://docs.atuin.sh/configuration/key-binding/#bash
export ATUIN_NOBIND="true"
eval "$(atuin init bash)"

# bind to ctrl-r, add any other bindings you want here too
bind -x '"\C-r": __atuin_history'

# bind to the up key, which depends on terminal mode
#bind -x '"\e[A": __atuin_history --shell-up-key-binding'
#bind -x '"\eOA": __atuin_history --shell-up-key-binding'
