if [ -d $HOME/.bashrc.d ]
then
    [ -n "${DEBUG:-}" ] && start_time0=$(date +%s.%3N)
    for bashrc in $HOME/.bashrc.d/*.bash; do
        [ -n "${DEBUG:-}" ] && start_time=$(date +%s.%3N)
        source $bashrc
        if [ -n "${DEBUG:-}" ]
        then
            end_time=$(date +%s.%3N)
            # elapsed time with millisecond resolution
            # keep three digits after floating point.
            elapsed=$(echo "scale=3; $end_time - $start_time" | bc)
            echo "*** took $elapsed seconds to source $bashrc"
        fi
    done
    if [ -n "${DEBUG:-}" ]
    then
        end_time0=$(date +%s.%3N)
        # elapsed time with millisecond resolution
        # keep three digits after floating point.
        elapsed0=$(echo "scale=3; $end_time0 - $start_time0" | bc)
        echo "=== took $elapsed0 seconds to source all"
    fi
    if [ -n "${DEBUG:-}" ]
    then
        unset start_time
        unset end_time
        unset elapsed
    fi
fi

### DEBUG INFO
# PS4='+$BASH_SOURCE> ' BASH_XTRACEFD=7 bash -xl 7>&2
## That will simulate a login shell and show everything that is done along
# with the name of the file currently being interpreted.
# So all you need to do is look for the name of your environment variable in
# that output. (you can use the script command to help you store the whole
# shell session output, or for the bash approach, use 7> file.log instead ofbashrc


. "$HOME/.atuin/bin/env"
