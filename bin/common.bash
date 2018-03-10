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

function ifdebug1() {
	# shellcheck disable=SC2153
	[ "${DEBUG}" -ge 1 ]
}

function ifdebug2() {
	[ "${DEBUG}" -ge 2 ]
}

function ifdebug3() {
	[ "${DEBUG}" -ge 3 ]
}

function ifinteractive() {
	tty --silent
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
		if ifdebug3
		then
			# shellcheck disable=SC2154
			notify "Setting debug level 3" "red"
			set -o xtrace
			set -o verbose
		elif ifdebug2
		then
			# shellcheck disable=SC2154
			notify "Setting debug level 2" "orange"
			set -o xtrace
			set -o functrace
		else
			# shellcheck disable=SC2154
			notify "Setting debug level 1" "blue"
		fi
	fi
}


function notify_stdout() {
	local message="$1"

	local color="${2-lightgrey}"
	local colorvar
	local echo_color
	colorvar="echo_${color}"
	echo_color="${!colorvar}"

	# shellcheck disable=SC2154
	echo -e "${echo_color}$(timestamp) ${message} (${SECONDS}s)${echo_normal}" >&1
}

function notify_stderr() {
	local message="$1"

	local color="${2-orange}"
	local colorvar
	local echo_color
	colorvar="echo_${color}"
	echo_color="${!colorvar}"

	# shellcheck disable=SC2154
	echo -e "${echo_color}$(timestamp) ${message} (${SECONDS}s)${echo_normal}" >&2
}

function notify() {
	local message="$1"

	local color="${2:-lightgray}"
	local colorvar
	local echo_color
	colorvar="echo_${color}"
	echo_color="${!colorvar}"

	notify_stdout "${message}" "${color}"
}

function notify_debug() {
	if ifdebug1
	then
		local message="$1"

		local color="${2-purple}"
		local colorvar
		local echo_color
		colorvar="echo_${color}"
		echo_color="${!colorvar}"

		notify_stderr "${message}" "${color}"
	fi
}

function _notify_libnotify() {
	# private function, do not call directly
	# called via notify_libnotify or notify_libnotify_debug
	local urgency
	local summary
	local body

	local color
	local NOGUI=1 # means false, same logic as rc

	if [ "$#" -eq 0 ]
	then
		errexit "Illegal number of parameters: " \
				"need '[low|normal|critical]' 'summary' 'body'"
	fi

	debug=${1}; shift
	urgency=${1:-"low"}; shift
	summary=${1:-"ERROR"}; shift
	body=${*:-"UNDEFINED"}

	case ${debug} in
		"DEBUG")
			NOTIFY="notify_debug"
			color="purple"
			;;
		"NODEBUG")
			NOTIFY="notify"
			;;
		*)
			errexit "Wrong debug parameter for _notify_libnotify. Need DEBUG"\
					"NODEBUG, got ''${debug}''."
			;;
	esac

	color="${color:-lightgray}"
	case $urgency in
		"low"|"normal")
			;;
		"critical")
			color="red"
			;;
		""|"nogui"|NOGUI)
			NOGUI=0
			;;
		*)
			errexit "First parameter should be one of '[low|normal|critical]'"
			;;
	esac

	if [ "${NOGUI}" -eq 0 ] # true
	then
		${NOTIFY} "${summary} - ${body}" "${color}"
	else
		${NOTIFY} "${summary}: ${body}" "${color}"
		notify-send --urgency="${urgency}" --icon=gtk-info \
					"${summary}" "${body}" || :
	fi
}

function notify_libnotify() {
	_notify_libnotify NODEBUG "$@"
}

function notify_libnotify_debug() {
	_notify_libnotify DEBUG "$@"
}

function notify_error() {
	local message=${1:-}
	local NOGUI

	if [ "${1-}" = "NOGUI" ]
	then
		shift
		NOGUI=0
	else
		NOGUI=1
	fi

	if [ -z "${message}" ]
	then
		message="UNDEFINED ERROR"
	else
		message="Error: $*"
	fi

	if [ "${NOGUI}" -eq 0 ] # true
	then
		notify "${message}" "red"
	else
		notify_libnotify critical ERROR "${message}"
	fi
}

function errexit() {
	local message=${1:-}
	if [ -z "${message}" ]
	then
		message="UNDEFINED ERROR"
	else
		message="$*"
	fi
	notify_error "ERROR: ${message}"
	exit 1
}

check_debug_logging
