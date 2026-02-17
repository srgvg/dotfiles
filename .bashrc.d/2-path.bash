PATH="$HOME/bin"

pathmunge $HOME/.local/lib/npm/bin after
pathmunge $HOME/bins after
pathmunge $HOME/bin2 after
pathmunge /usr/local/bin after
pathmunge /usr/local/sbin after
pathmunge /usr/bin after
pathmunge /usr/sbin after

# mise shims are now handled by 3-mise.bash with proper safeguards

export PATH
