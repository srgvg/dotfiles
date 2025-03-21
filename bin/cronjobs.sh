#!/usr/bin/env bash

# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t
# vi: set shiftwidth=4 tabstop=4 noexpandtab:
# :indentSize=4:tabSize=4:noTabs=false:

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -o nounset
set -o errexit
set -o pipefail

# shellcheck disable=SC1090
source "$HOME/bin/common.bash"

#######################################################################################################################

command=${1:-default}

#######################################################################################################################

function log() {
	local command
	local logfile
	command=${1-:default}
	logfile="$HOME/logs/cronjobs/$(date +%H)-$(hostname)-${command}.log"
	mkdir -p "$(dirname ${logfile})"
	tee ${logfile}
	# delete file if empty
	test -s  ${logfile} || rm ${logfile}
	find $HOME/logs/cronjobs \
		-print0 \
		-mindepth 1 \
		-cmin +1440 \
		-type f \
		| xargs -0 rm -rfv
}

#######################################################################################################################

function execute() {
	local command
	command=${1-:default}

	###############################################################################
	if [ "${command}" = "rm-scratch-files" ]
	then

		nice -n 20 ionice -c 3 \
			find $HOME/scratch/ \
			-print0 \
			-mindepth 1 \
			-not -path '/home/serge/scratch/work/*' -a -not -path '/home/serge/scratch/.stfolder*' \
			-cmin +2880 \
			\( -type f -o -type l \) \
			| xargs -0 rm -rfv

	###############################################################################
	elif [ "${command}" = "rm-scratch-dirs" ]
	then
		nice -n 20 ionice -c 3 \
			find $HOME/scratch/ \
			-print0 \
			-depth -mindepth 1 \
			-not -path '/home/serge/scratch/.stfolder*' -not -path '/home/serge/scratch/work**' \
			-type d \
			-empty \
			| xargs -0 rm -rfv

	###############################################################################
	elif [ "${command}" = "restore-dirs" ]
	then

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

		crontab -l > $HOME/etc/crontab

	###############################################################################
	else
		return 7
	fi
}

#######################################################################################################################

execute ${command} |& ts | log ${command}
if [ $? -eq 7 ]
then
	echo no actions for ${command}
fi

