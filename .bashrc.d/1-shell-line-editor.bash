# Line editor selection (ble.sh vs flyline). Must load before blesh.bash --
# hence the "1-" prefix -- since blesh.bash (unprefixed) reads this var to
# decide whether to source ble.sh at all. z95_flyline.bash reads it too.
# See ~/etc/docs/shell-setup.md#line-editor-toggle-blesh-vs-flyline
# Rollback: unset/delete this line (reverts to ble.sh next shell), or
# `enable -d flyline` mid-session.
export SHELL_LINE_EDITOR=flyline
