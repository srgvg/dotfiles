#!/usr/bin/env bash

# Loads the system's Bash completion modules.
# If Homebrew is installed (OS X), its Bash completion modules are loaded.
#
# Deferred loading: System completions are loaded on first tab press.
# This saves ~30ms on every shell startup.

_deferred_bash_completion_loaded=false

_load_system_completions() {
    if [[ "$_deferred_bash_completion_loaded" == "false" ]]; then
        _deferred_bash_completion_loaded=true

        if [ -f /etc/bash_completion ]; then
          . /etc/bash_completion
        fi

        # Some distribution makes use of a profile.d script to import completion.
        if [ -f /etc/profile.d/bash_completion.sh ]; then
          . /etc/profile.d/bash_completion.sh
        fi

        if [ $(uname) = "Darwin" ] && command -v brew &>/dev/null ; then
          BREW_PREFIX=$(brew --prefix)

          if [ -f "$BREW_PREFIX"/etc/bash_completion ]; then
            . "$BREW_PREFIX"/etc/bash_completion
          fi

         # homebrew/versions/bash-completion2 (required for projects.completion.bash) is installed to this path
          if [ "${BASH_VERSINFO}" -ge 4 ] && [ -f "$BREW_PREFIX"/share/bash-completion/bash_completion ]; then
            export BASH_COMPLETION_COMPAT_DIR="$BREW_PREFIX"/etc/bash_completion.d
            . "$BREW_PREFIX"/share/bash-completion/bash_completion
          fi
        fi
    fi
}

# Load on first completion attempt
complete -D -F _load_system_completions -o default
