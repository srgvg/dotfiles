#!/usr/bin/env bash

# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t
# vi: set shiftwidth=4 tabstop=4 expandtab:
# :indentSize=4:tabSize=4:noTabs=false:

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -o nounset
set -o errexit
#set -o pipefail

# shellcheck disable=SC1090
source "$HOME/bin/common.bash"

#######################################################################################################################

command=${1:-default}

LOGDIR="${HOME}/logs/cronjobs"

#######################################################################################################################

function log() {
    local command
    local logfile
    command=${1:-default}
    logfile="${LOGDIR}/$(hostname)-${command}-$(date +%y%m%d%H).log"
    mkdir -p "$(dirname "${logfile}")"
    tee "${logfile}"
    # delete file if empty
    test -s "${logfile}" || rm "${logfile}"
}

function logline() {
    echo "# $*"
}
function logtitle() {
    echo
    echo "### $*"
    echo
}

#######################################################################################################################

function execute() {
    local command
    command=${1:-default}

    ###############################################################################
    if [ "${command}" = "cleanup" ]; then

        cleantime="+2880" # 48 hours
        tempfolders="$HOME/scratch/grabs $HOME/scratch/temp $HOME/scratch/tmp $HOME/scratch/t $HOME/tmp/"

        # cleanup files:
        # files in ~/scratch/ itself
        logtitle Looking for files in ~/scratch itself
        nice -n 20 ionice -c 3 find \
            $HOME/scratch/ \
            $HOME/tmp/
        -maxdepth 1 \
            -not -path '/home/serge/scratch/.stfolder' \
            -not -path '/home/serge/scratch/.stignore' \
            -mmin ${cleantime} \( -type f -o -type l \) \
            -print0 | xargs -r -0 rm -fv

        # files in ~/scratch/grabs/ and other temp folders
        logtitle looking for files in temp folders
        nice -n 20 ionice -c 3 find \
            ${tempfolders} \
            -depth -mindepth 1 \
            -mmin ${cleantime} \( -type f -o -type l \) \
            -print0 | xargs -r -0 rm -fv

        # cleanup empty directories
        logtitle looking for empty dirs in temp folders
        nice -n 20 ionice -c 3 find \
            $HOME/scratch/ \
            -depth -mindepth 2 \
            -not -path '/home/serge/scratch/.stfolder*' \
            -type d -empty \
            -print0 | xargs -r -0 rmdir --parents -verbose

        logtitle misc stuff

        # syncthing needs
        if ! test -d /home/serge/scratch/.stfolder; then
            logline fix syncthing folder
            rm -rfv /home/serge/scratch/.stfolder
            mkdir -pv /home/serge/scratch/.stfolder
        fi

        # ms edge crap
        rm -fv $HOME/core.*

        # cleanup logs
        logtitle cleanup my logs
        find $HOME/logs \
            -mindepth 1 \
            -mmin +11520 \
            -type f \
            -delete

        # cleanupo claude files
        logtitle cleanup ~/.claude files
        ## Archive todos older than 30 days - Run daily at 2:30 AM
        find $HOME/.claude/todos/ \
            -type f -name "*.json" \
            -mtime +30 \
            -delete
        # Delete shell snapshots older than 7 days
        find $HOME/.claude/shell-snapshots/ \
            -type f -name "snapshot-*.sh" \
            -mtime +7 \
            -delete

    ###############################################################################
    elif [ "${command}" = "update-tools" ]; then

        $HOME/bin/update-tools

    ###############################################################################
    elif [ "${command}" = "backup" ]; then

        : # no-op

    ###############################################################################
    elif [ "${command}" = "picwide" ]; then

        $HOME/bin/picwide --verbose --update
        PICWIDE_OUTPUT=$HOME/Wallpapers/ultrawide3 PICWIDE_MIN_WIDTH="3600" PICWIDE_MIN_RATIO="3" $HOME/bin/picwide --verbose --update

    ###############################################################################
    elif [ "${command}" = "default" ]; then
        echo "supported options:"
        grep 'if .* "${command}" = ' ~/bin/cronjobs.sh | grep -v grep | cut -d\" -f4 | sed s/'^/  - /'

    ###############################################################################
    else
        echo no actions for ${command}
        return 7
    fi

    ###############################################################################
    if [ "$(hostname)" = "goldorak" ]; then
        crontab -l >$HOME/etc/crontab
    fi
}

#######################################################################################################################

execute ${command} |& ts | log ${command}

#######################################################################################################################
