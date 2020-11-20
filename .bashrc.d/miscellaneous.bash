# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# ls(1)
eval $(dircolors)

# grep colors - see man page
GREP_COLORS='mt=1;33:fn=37:se=2;37'
