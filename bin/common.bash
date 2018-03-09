#!/bin/bash
# shellcheck disable=SC1090

# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t
# vi: set shiftwidth=4 tabstop=4 noexpandtab:
# :indentSize=4:tabSize=4:noTabs=false:

PATH=$HOME/bin:$PATH
source $HOME/bin/parameters.bash
source $HOME/.bash_it/custom/functions.bash

function timestamp() {
	date +%Y%m%d-%H%M
}

function ifdebug() {
	if [ -n "${DEBUG}" ]
	then
		return 0
	else
		return 1
	fi
}

function ifdebug0() {
	if ifdebug && [ "${DEBUG}" -ge 0 ]
	then
		return 0
	else
		return 1
	fi
}

function ifdebug1() {
	if ifdebug && [ "${DEBUG}" -ge 1 ]
	then
		return 0
	else
		return 1
	fi
}

function ifdebug2() {
	if ifdebug && [ "${DEBUG}" -ge 2 ]
	then
		return 0
	else
		return 1
	fi
}

function ifdebug3() {
	if ifdebug && [ "${DEBUG}" -ge 3 ]
	then
		return 0
	else
		return 1
	fi
}

function _time() {
	if which time >/dev/null
	then
		# shellcheck disable=SC2048
		/usr/bin/time --format %E $*
	else
		# shellcheck disable=SC2048
		time $*
	fi
}

function time2() {
	info="${1:-}"
	if [ -z "${info}" ]
	then
		all="sleep 0"
	else
		all="$*"
	fi
	notify_debug "Executing: ${all}"
	duration="$(_time ${all} 2>&1)"
	notify "Execution of ${info} took ${duration}s."
}

function check_debug_logging() {
	if ifdebug1
	then
		# log this scripts full output
		LOGFILE="$(readlink -f "$0" | sed -e 's@/home/serge/@@' \
					-e 's@/@_@g' -e 's@ @@g').log"
		LOGFILE="$LOGS_PATH/${LOGFILE}"
		exec &> >(tee "${LOGFILE}")
		if ifdebug2
		then
			set -o xtrace
		fi
	fi
}

function notify1() {
	local message="$*"
	echo "$(timestamp) ${message} (${SECONDS}s)" >&1
}

function notify2() {
	local message="$*"
	echo "$(timestamp) ${message} (${SECONDS}s)" >&2
}

function notify() {
	local message="$*"
	notify2 "${message}"
}

function notify_debug() {
	if ifdebug1
	then
		local message="$*"
		notify "${message}"
	fi
}

function notify_libnotify() {
	local urgency
	local summary
	local body

	local NOGUI=0

	if [ "$#" -eq 0 ]
	then
		errexit "Illegal number of parameters: " \
				"need '[low|normal|critical]' 'summary' 'body'"
	fi

	urgency=${1:-"low"}; shift
	summary=${1:-"ERROR"}; shift
	body=${*:-"UNDEFINED"}

	#	# if running in a terminal
	#	if [ -t 1 ]
	#	then

	case $urgency in
		"low"|"normal"|"critical")
			:
			;;
		""|"nogui"|NOGUI)
			NOGUI=1
			;;
		*)
			errexit "First parameter should be one of '[low|normal|critical]'"
			;;
	esac

	if [ "${NOGUI}" -eq 1 ]
	then
		notify "${summary} - ${body}"
	else
		notify "${summary} - (${urgency}) - ${body}"
		notify-send --urgency="${urgency}" --icon=gtk-info \
					"${summary}" "${body}" || :
	fi
}

function notify_error() {
	local message=${1:-}
	if [ -z "${message}" ]
	then
		message="UNDEFINED ERROR"
	else
		message="Error: $*"
	fi
	notify_libnotify critical ERROR "${message}"
}

function errexit() {
	local message=${1:-}
	if [ -z "${message}" ]
	then
		message="UNDEFINED ERROR"
	else
		message="$*"
	fi
	notify "Error: ${message}"
	notify_error "${message}"
	exit 1
}

