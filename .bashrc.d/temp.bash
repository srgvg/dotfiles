# systemd --user
export XDG_RUNTIME_DIR="/run/user/$UID"

alias civo="docker run -it --rm -v $HOME/.civo.json:/home/user/.civo.json civo/cli:latest"
