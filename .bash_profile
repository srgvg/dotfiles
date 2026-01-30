# ~/.bash_profile: executed by bash(1) for login shells.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/login.defs
#umask 022

# include .bashrc if it exists
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

# NOTE: Atuin sourcing removed from here (was redundant)
# Atuin is now loaded only once via ~/.bashrc.d/atuin.bash
# This prevents loading atuin 4x on shell startup
