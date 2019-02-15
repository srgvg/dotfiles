#!/usr/bin/env bash

# Path to the bash it configuration
export BASH_IT="/home/serge/.bash_it"

# Lock and Load a custom theme file
# location /.bash_it/themes/
export BASH_IT_THEME='serge'

# Your place for hosting Git repos. I use this for private repos.
#export GIT_HOSTING='git@git.ginsys.eu'

# Don't check mail when opening terminal.
unset MAILCHECK

# Change this to your console based IRC client of choice.
export IRC_CLIENT='/home/serge/bin/irc'

# Set this to the command you use for todo.txt-cli
export TODO="t"

# Set this to false to turn off version control status checking within the prompt for all themes
export SCM_CHECK=true

# Set vcprompt executable path for scm advance info in prompt (demula theme)
# https://github.com/xvzf/vcprompt
#export VCPROMPT_EXECUTABLE=~/.vcprompt/bin/vcprompt

# Load Bash It
source $BASH_IT/bash_it.sh

# custom things go here
if [ -d $HOME/.bashrc.d ]
then
    source $HOME/.bashrc.d/*
fi


### DEBUG INFO
# PS4='+$BASH_SOURCE> ' BASH_XTRACEFD=7 bash -xl 7>&2
## That will simulate a login shell and show everything that is done along
# with the name of the file currently being interpreted.
# So all you need to do is look for the name of your environment variable in
# that output. (you can use the script command to help you store the whole
# shell session output, or for the bash approach, use 7> file.log instead of
# 7>&2 to store the xtrace output to file.log instead of on the terminal).
