# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# ls(1) - use pre-generated dircolors cache (regenerated hourly via update-tools)
# To manually regenerate: update-tools shell-init
_dircolors_cache="$HOME/.cache/shell-init/dircolors.bash"
if [[ -f "$_dircolors_cache" ]]; then
    source "$_dircolors_cache"
else
    # Fallback if cache missing (first run)
    eval $(dircolors)
fi
unset _dircolors_cache

# grep colors - see man page
# NOTE: Added 'export' - was missing, preventing GREP_COLORS from being
# visible to child processes and grep command itself
export GREP_COLORS='mt=1;33:fn=37:se=2;37'
