#!/usr/bin/env bash

umask 0022

# most things go here
if [ -d $HOME/.bashrc.d ]
then
    for bashrc in $HOME/.bashrc.d/*.bash; do
        source $bashrc
    done
fi

# starship shell prompt stuff
# https://starship.rs/
eval "$(starship init bash)"
# to update startship:
# bash <(curl -fsSL https://starship.rs/install.sh) --verbose --bin-dir $HOME/bin2 --yes

### DEBUG INFO
# PS4='+$BASH_SOURCE> ' BASH_XTRACEFD=7 bash -xl 7>&2
## That will simulate a login shell and show everything that is done along
# with the name of the file currently being interpreted.
# So all you need to do is look for the name of your environment variable in
# that output. (you can use the script command to help you store the whole
# shell session output, or for the bash approach, use 7> file.log instead of
