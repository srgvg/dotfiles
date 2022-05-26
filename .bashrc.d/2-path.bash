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
pathmunge $HOME/bin
pathmunge $HOME/bins
pathmunge $HOME/bin2
pathmunge $HOME/.local/bin after
pathmunge $HOME/.krew/bin after
pathmunge $HOME/.cargo/bin after
pathmunge $HOME/.screenlayout after
pathmunge $HOME/Documents/Applications/google-cloud-sdk/bin after
