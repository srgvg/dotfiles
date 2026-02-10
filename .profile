# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi

# NOTE: Atuin sourcing removed from here (was redundant and caused
# atuin to be loaded 4 times on shell startup)
# Atuin is now loaded only once via ~/.bashrc.d/atuin.bash
#
# NOTE: This file is NOT read by bash if ~/.bash_profile exists
# (which it does). Keep this minimal for POSIX shell compatibility
# (dash, sh, etc.) only.

# Optional: source POSIX shell config from .profile.d/
# if [ -d "$HOME/.profile.d" ]; then
#     for f in "$HOME/.profile.d"/*.sh; do
#         [ -r "$f" ] && . "$f"
#     done
# fi
