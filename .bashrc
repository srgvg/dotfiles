if [ -d $HOME/.bashrc.d ]
then
    for bashrc in $HOME/.bashrc.d/*.bash; do
        source $bashrc
    done
fi

### DEBUG INFO
# PS4='+$BASH_SOURCE> ' BASH_XTRACEFD=7 bash -xl 7>&2
## That will simulate a login shell and show everything that is done along
# with the name of the file currently being interpreted.
# So all you need to do is look for the name of your environment variable in
# that output. (you can use the script command to help you store the whole
# shell session output, or for the bash approach, use 7> file.log instead of
