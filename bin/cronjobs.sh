#!/usr/bin/env bash

# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t
# vi: set shiftwidth=4 tabstop=4 expandtab:
# :indentSize=4:tabSize=4:noTabs=false:

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -o nounset
set -o errexit
set -o pipefail

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
	test -s  ${logfile} || rm ${logfile}
}

#######################################################################################################################

function execute() {
	local command
	command=${1-:default}

	###############################################################################
	if [ "${command}" = "cleanup" ]
	then

		nice -n 20 ionice -c 3 \
			find $HOME/scratch/ \
			-mindepth 1 \
			-not -path '/home/serge/scratch/work/*' -a -not -path '/home/serge/scratch/.stfolder*' \
			-mmin +2880 \
			\( -type f -o -type l \) \
			-print0 \
			| xargs -r -0 rm -fv

		nice -n 20 ionice -c 3 \
			find $HOME/scratch/ \
			-depth -mindepth 1 \
			-not -path '/home/serge/scratch/.stfolder*' -not -path '/home/serge/scratch/work**' \
			-type d \
			-empty \
			-print0 \
			| xargs -r -0 rmdir -v

		if ! test -d /home/serge/scratch/.stfolder
		then
			rm -rfv /home/serge/scratch/.stfolder
			mkdir -pv /home/serge/scratch/.stfolder
		fi
		if ! test -d /home/serge/scratch/work
		then
			rm -rfv /home/serge/scratch/work
			mkdir -pv /home/serge/scratch/work
		fi

		find $HOME/logs/cronjobs \
			-mindepth 1 \
			-mmin +4500 \
			-type f \
			-delete

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
if [ $? -eq 7 ]
then
	echo no actions for ${command}
fi

#######################################################################################################################

