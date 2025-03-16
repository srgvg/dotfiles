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

###############################################################################

command=${1:-default}


function log() {
	local command
	local logfile
	command=${1-:default}
	logfile="$HOME/logs/${command}-$(hostname)-$(date +%H).log"
	cat > ${logfile}
	# delete file if empty
	test -s  ${logfile} || rm ${logfile}
}


function execute() {
	local command
	command=${1-:default}

	###############################################################################
	if [ "${command}" = "rm-scratch-files" ]
	then

		nice -n 20 ionice -c 3 \
			find $HOME/scratch/ \
			-mindepth 1 \
			-not -path '/home/serge/scratch/work/*' -a -not -path '/home/serge/scratch/.stfolder*' \
			-cmin +2880 \
			\( -type f -o -type l \) \
			| xargs rm -rfv

	###############################################################################
	elif [ "${command}" = "rm-scratch-dirs" ]
	then
		nice -n 20 ionice -c 3 \
			find $HOME/scratch/ \
			-depth -mindepth 1 \
			-not -path '/home/serge/scratch/.stfolder*' -not -path '/home/serge/scratch/work**' \
			-type d \
			-empty \
			| xargs rm -rfv

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
		echo saving crontab
		crontab -l | tee $HOME/etc/crontab

	###############################################################################
	fi
}


if		[ "${command}" = "rm-scratch-files" ] \
	||	[ "${command}" = "rm-scratch-dirs" ] \
	||	[ "${command}" = "restore-dirs" ] \
	||	[ "${command}" = "update-tools" ] \
	|| 	[ "${command}" = "backup-vaultwarden" ] \
	|| 	[ "${command}" = "default" ]
then
	execute ${command} |& ts | log ${command}
else
	echo no actions for ${command}
fi





