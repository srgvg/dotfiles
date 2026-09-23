PATH="$HOME/bin"

pathmunge $HOME/bins after
pathmunge $HOME/binc after
pathmunge $HOME/bin2 after
pathmunge $HOME/.local/lib/npm/bin after
# ~/.cargo/bin is deliberately absent: mise's global `rust` tool owns it and puts it in its own
# section, ahead of Debian's older /usr/bin/cargo. Adding it here made mise move it to the very
# end after the first `cd`, behind /usr/bin.
pathmunge /usr/local/bin after
pathmunge /usr/local/sbin after
pathmunge /usr/bin after
pathmunge /usr/sbin after

# mise shims are now handled by z80_mise.bash with proper safeguards

export PATH
