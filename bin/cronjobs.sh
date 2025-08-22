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
	command=${1-:default}
	logfile="${LOGDIR}/$(hostname)-${command}-$(date +%y%m%d%H).log"
	mkdir -p "$(dirname ${logfile})"
	tee ${logfile}
	# delete file if empty
	test -s ${logfile} || rm ${logfile}
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
	command=${1-:default}

	###############################################################################
	if [ "${command}" = "cleanup" ]
	then

	    cleantime="+2880" # 48 hours
	    tempfolders="$HOME/scratch/grabs $HOME/scratch/temp $HOME/scratch/tmp $HOME/scratch/t"

        # cleanup files:
        # files in ~/scratch/ itself
        logtitle Looking for files in ~/scratch itself
		nice -n 20 ionice -c 3 find \
		    $HOME/scratch/ \
			-maxdepth 1 \
			-not -path '/home/serge/scratch/.stfolder' \
			-not -path '/home/serge/scratch/.stignore' \
			-mmin ${cleantime} \( -type f -o -type l \) \
			-print0 | xargs -r -0 rm -fv

        # files in ~/scratch/grabs/ and other temp folders
        logtitle looking for files in temp folders
		nice -n 20 ionice -c 3 find \
			${tempfolders} \
			-maxdepth 1 \
			-mmin ${cleantime} \( -type f -o -type l \) \
			-print0 | xargs -r -0 rm -fv

        # cleanup empty directories
        logtitle looking for empty dirs in temp folders
		nice -n 20 ionice -c 3 find \
			${tempfolders} \
			-depth -mindepth 1 \
			-not -path '/home/serge/scratch/.stfolder*' \
			-type d -empty \
			-print0 | xargs -r -0 rmdir -v

        logtitle misc stuff

        # syncthing needs
		if ! test -d /home/serge/scratch/.stfolder
		then
		    logline fix syncthing folder
			rm -rfv /home/serge/scratch/.stfolder
			mkdir -pv /home/serge/scratch/.stfolder
		fi

        # ms edge crap
		rm -fv $HOME/core.*

        # cleanup logs
        logtitle cleanup my logs
		find $HOME/logs/cronjobs \
			-mindepth 1 \
			-mmin +4500 \
			-type f \
			-delete

		# cleanupo claude files
		logtitle cleanup ~/.claude files
		## Archive todos older than 30 days - Run daily at 2:30 AM
        find $HOME/.claude/todos/ \
            -type f -name "*.json" \
            -mtime +30 \
            -delete
        # Dekete shell snapshots older than 7 days
        find $HOME/.claude/shell-snapshots/ \
            -type f -name "snapshot-*.sh" \
            -mtime +7 \
            -delete

  2>/dev/null

	###############################################################################
	elif [ "${command}" = "update-tools" ]
	then

		$HOME/bin/update-tools

	###############################################################################
	elif [ "${command}" = "backup-vaultwarden" ]
	then

		$HOME/bins/backup-vaultwarden.sh

	###############################################################################
	elif [ "${command}" = "default" ]
	then
		:

	###############################################################################
	else
	    echo no actions for ${command}
		return 7
	fi

	###############################################################################
	if [ "$(hostname)" = "goldorak" ]
	then
	    crontab -l > $HOME/etc/crontab
	fi
}

#######################################################################################################################

execute ${command} |& ts | log ${command}

#######################################################################################################################

