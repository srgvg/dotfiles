# GOBIN is set by mise's global [env] (~/.local/bin, see ~/etc/docs/go.md); mise's hook runs
# after this file and always overrode a value here.
export GOPATH="$HOME/.cache/go"         # or $HOME/go if you preferi
export GOMODCACHE="$GOPATH/pkg/mod"     # default
export GOCACHE="$HOME/.cache/go-build"  # default-ish

