export NVM_DIR="$HOME/.nvm"

# NOTE: Lazy loading implementation replaces direct sourcing
# OLD (slow): [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
# NEW (fast): Functions that load NVM only when first used
#
# This dramatically improves shell startup time by deferring the
# 54KB+ NVM script load until you actually use nvm/node/npm/npx.
# First call triggers NVM load, subsequent calls use real commands.

nvm() {
    unset -f nvm node npm npx
    [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
    nvm "$@"
}

node() { nvm --version >/dev/null; unset -f node; node "$@"; }
npm() { nvm --version >/dev/null; unset -f npm; npm "$@"; }
npx() { nvm --version >/dev/null; unset -f npx; npx "$@"; }

