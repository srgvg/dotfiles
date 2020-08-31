# don't put duplicate lines in the history. See bash(1) for more options
# ... or force ignoredups and ignorespace
HISTCONTROL=ignoreboth

# HISTIGNORE is a colon-separated list of patterns used to decide which
# command lines should be saved in the history file.
# Don’t save ls, ps and history commands:
#HISTIGNORE="ls:ps:history"
HISTIGNORE="history"

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=20000
HISTFILESIZE=100000

HISTTIMEFORMAT="%h %d %H:%M:%S "

# append to the history file, don't overwrite it
shopt -s histappend

# Store multi-line commands in one history entry:
shopt -s cmdhist

