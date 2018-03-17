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

function _check_debug_logging() {
	if ifdebug1 || [ -n "${FORCE_DEBUG_LOGGING:-}" ]
	then
		# log this scripts full output
		LOGFILE="$(readlink -f "$0" | sed -e 's@/home/serge/@@' \
					-e 's@/@_@g' -e 's@ @@g').log"
		LOGFILE="$LOGS_PATH/${LOGFILE}"
		exec &> >(tee >(sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" >"${LOGFILE}"))

		if ifdebug3
		then
			COLOR_DEBUG="red"
			set -o xtrace
			set -o functrace
			set -o verbose
			# automatically debug subprocesses too
			export DEBUG
			local thisfile="${BASH_SOURCE[0]}"
			notify_debug "List of available functions in ${thisfile}: $(grep '^function' "${thisfile}" |
				awk '{print $2}' | grep -v '^_' | sort | xargs)" "${COLOR_DEBUG}"
		elif ifdebug2
		then
			COLOR_DEBUG="orange"
			set -o xtrace
			set -o functrace
		else #ifdebug1
			COLOR_DEBUG="purple"
		fi
		# shellcheck disable=SC2154
		notify_debug "DEBUG LEVEL ${DEBUG} FROM ${BASH_SOURCE[*]}" "${COLOR_DEBUG}"
	fi
}


function _notify_stdout() {
	# private function

	if ifinteractive
	then
		local message="${1:-}"

		local color="${2:-white}"
		local colorvar
		local echo_color
		colorvar="echo_${color}"
		echo_color="${!colorvar}"

		# shellcheck disable=SC2154
		echo -e "${echo_color}$(timestamp) ${message} (${SECONDS}s)${echo_normal}" >&1
	fi
}

function _notify_stderr() {
	# private function

	local message="${1:-UNKNOWN ERROR}"
	local color="${2:-red}"
	local colorvar
	local echo_color
	colorvar="echo_${color}"
	echo_color="${!colorvar}"

	# shellcheck disable=SC2154
	echo -e "${echo_color}$(timestamp) ${message} (${SECONDS}s)${echo_normal}" >&2
}

function notify() {
	local message="${1:-}"
	local color="${2:-lightgray}"
	_notify_stdout "${message}" "${color}"
}

function notify_debug() {
	if ifdebug1
	then
		local message="${1:-}"
		local color="${2:-lightgray}"
		_notify_stderr "${message}" "${color}"
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
	_notify_stderr "${message}" "red"
}

function errexit() {
	local message=${1:-}

	notify_error "${message}" >&2
	exit 1
}

function notify_desktop() {
	if ! ifinteractive
	then
		local numparam=3
		[ $# -eq ${numparam} ] || errexit "function ${FUNCNAME[0]} expects ${numparam} parameters, got $#: '$#'"

		local urgency
		local summary
		local body
		local color

		urgency=${1}
		summary=${2}
		body=${3}

		case $urgency in
			"low")
				color="lightgray"
				;;
			"normal")
				color="white"
				;;
			"critical")
				color="red"
				;;
			*)
				errexit "First parameter should be one of '[low|normal|critical]'"
				;;
		esac

		notify-send --urgency="${urgency}" --icon=gtk-info \
					"${summary}" "${body}" || :
	fi
}

function notify2() {
	local message="${1:-}"
	notify "${message}"
	notify_desktop normal "${BASH_SOURCE[0]}" "${message}"
}

function notify_error_desktop() {
	local message=${1:-}

	if [ -z "${message}" ]
	then
		message="UNDEFINED ERROR"
	else
		message="$*"
	fi
	notify_desktop critical ERROR "${message}"
}

function errexit_desktop() {
	local message=${1:-}

	notify_error_desktop "${message}"
	errexit "${message}"
}


_check_debug_logging
