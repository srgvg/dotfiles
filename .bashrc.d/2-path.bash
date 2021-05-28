#
## PATH #
#

# reset
export PATH="/usr/local/bin:/usr/bin:/bin"
# add sbin paths (not default in Debian)
export PATH="$PATH:/usr/local/sbin:/usr/sbin:/sbin"
export PATH="$PATH:/usr/local/games:/usr/games"

pathmunge /snap/bin

## GOPATH
export GOPATH=$HOME/go
pathmunge ${GOPATH}/bin

## set PATH so it includes various user's private bin dirs
pathmunge $HOME/.local/bin
pathmunge $HOME/.arkade/bin
pathmunge $HOME/.krew/bin
pathmunge $HOME/bin
pathmunge $HOME/bins
pathmunge $HOME/bin2
pathmunge $HOME/.screenlayout after
