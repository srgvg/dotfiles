## SSH Agent
# if interactive
if ! grep -q sway /proc/$$/cmdline ; then
if [[ -t 0 ]] ; then
if [   "${HOSTNAME}" = "goldorak" ] || [ "${HOSTNAME}" = "minos" ] || [ "${HOSTNAME}" = "cyberlab" ] || [ "${HOSTNAME}" = "fregolo" ]
then
    # re-use keychain agents if available
    if [ -f ~/.keychain/${HOSTNAME}-sh ]
    then
      # shellcheck disable=SC1090
    	source ~/.keychain/${HOSTNAME}-sh
    fi

    # check if extglob is already set (this script gets SOURCED and bash_it does stuff
    if [[ $(shopt extglob) =~ on ]]
    then
      EXTGLOB=1
    else
      EXTGLOB=0
      shopt -s extglob
    fi
    if [ -x "$(which keychain)" ]
    then
	    #[ -z "$SSH_CLIENT" ] && [ -z "$SSH_TTY" ] \
        eval "`
                keychain \
                --lockwait 300 \
                --quiet \
                --attempts 2 \
                --inherit local \
                --nogui \
                --agents ssh,gpg \
                --gpg2 \
                --eval \
                --ignore-missing \
                ~/.ssh/id_!(*.pub) \
                3148E9B9232D65E5  \
             `"
    fi
        # to list the key id's:
        # gpg --list-secret-keys | grep sec | sed 's/.*\/0x//' | cut -d\  -f1
        #    D08FC082B8E46E8E \
        #    3148E9B9232D65E5 \
    if [ "${EXTGLOB}" -eq 0 ]
    then
      shopt -u extglob
    fi
fi; fi; fi

