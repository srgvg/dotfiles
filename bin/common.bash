#!/bin/bash
# shellcheck disable=SC1090

# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t
# vi: set shiftwidth=4 tabstop=4 expandtab:
# :indentSize=4:tabSize=4:noTabs=false:

PATH=$HOME/bin:$PATH
source "$HOME/bin/parameters.bash"
source "$HOME/.bashrc.d/functions.bash"
# Use shims for non-interactive scripts (faster than eval "$(mise env -s bash)")
export PATH="$HOME/.local/share/mise/shims:$PATH"


# make sure DEBUG is not exported
# it is when called 'DEBUG=1 foo.sh'
_DEBUG="${DEBUG:-0}" ; unset DEBUG
DEBUG="${_DEBUG}"    ; unset _DEBUG

function timestamp() {
	date +%Y%m%d-%H%M%S
}

function timestamp2() {
	date +%Y-%m-%d-%H:%M:%S
}

function ts() {
	/usr/bin/ts '%Y/%m/%d-%H:%M:%.S'
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

function set_xtrace() {
	if ifdebug2
	then
		set -o xtrace
	fi
}

function ifinteractive() {
	# https://stackoverflow.com/questions/3214935/can-a-bash-script-tell-if-its-being-run-via-cron
	# 1 is STDOUT
	[ -t 1  ]
}

function _time() {
	if command -v time >/dev/null
	then
		/usr/bin/time --format %E "$@"
	else
		time "$@"
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
	duration="$(_time "$@" 2>&1)"
	notify "Execution of ${info} took ${duration}s."
}

function _check_debug_logging() {
	if ifdebug1 || [ -n "${FORCE_DEBUG_LOGGING:-}" ]
	then
		# log this scripts full output
		mkdir -p "${LOGS_PATH}"
		LOGFILE="$(readlink -f "$0" | sed -e 's@/home/serge/@@' \
					-e 's@/@_@g' -e 's@ @@g').log"
		LOGFILE="$LOGS_PATH/${LOGFILE}"
		exec &> >(tee >(sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" | ts >"${LOGFILE}"))

		if ifdebug3
		then
			COLOR_DEBUG="red"
			set -o functrace
			set -o verbose
			local thisfile="${BASH_SOURCE[0]}"
			notify_debug "List of available functions in ${thisfile}: $(grep '^function' "${thisfile}" |
				awk '{print $2}' | grep -v '^_' | sort | xargs)" "${COLOR_DEBUG}"
		elif ifdebug2
		then
			COLOR_DEBUG="yellow"
			set -o functrace
		else #ifdebug1
			COLOR_DEBUG="green"
		fi
		# shellcheck disable=SC2154
		notify_debug "DEBUG LEVEL ${DEBUG} FROM ${BASH_SOURCE[*]}" "${COLOR_DEBUG}"
		# set_xtrace already executed at the end of notify_debug
	fi
}


function _notify_stdout() {
	# private function

	local message="${1:-}"

	local color="${2:-white}"
	local colorvar
	local echo_color
	colorvar="echo_${color}"
	echo_color="${!colorvar}"

	# shellcheck disable=SC2154
	echo -e "${echo_color}$(timestamp) ${message} (${SECONDS}s)${echo_normal}" >&1
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
	{ set +x; } 2>/dev/null
	local message="${1:-}"
	local color="${2:-lightgray}"
	_notify_stdout "${message}" "${color}"
	set_xtrace
}

function notify_debug() {
	{ set +x; } 2>/dev/null
	if ifdebug1
	then
		local message="${1:-}"
		local color="${COLOR_DEBUG:-lightgray}"
		_notify_stderr "${message}" "${color}"
	fi
	set_xtrace
}

function notify_error() {
	{ set +x; } 2>/dev/null
	local message=${1:-}

	if [ -z "${message}" ]
	then
		message="UNDEFINED ERROR"
	else
		message="Error: $*"
	fi
	_notify_stderr "${message}" "red"
	set_xtrace
}

function errexit() {
	{ set +x; } 2>/dev/null
	local message=${1:-}

	notify_error "${message}" >&2
	exit 1
}

function parse_notify_desktop() {
	local numparam=3
	[ $# -ge ${numparam} ] || errexit "function ${FUNCNAME[0]} expects at least ${numparam} parameters, got $#: '$#'"

	urgency=${1}
	summary=${2}
	body=${3}
	icon=${4:-dialog-info}
	app=${5:-$(basename "$0")}

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
}

function notify_desktop() {
	{ set +x; } 2>/dev/null

	local urgency
	local summary
	local body
	local color
	local icon
	local app

	parse_notify_desktop "$@"

	if  ! ifinteractive
	then
		notify-send --urgency="${urgency}" --icon="${icon}" --app-name="${app}" "${summary}" "${body}" -h string:x-canonical-private-synchronous:"${app}" ||:
	else
		notify "${summary} ${body}"
	fi
	set_xtrace
}

function notify_desktop_always() {
	{ set +x; } 2>/dev/null

	local urgency
	local summary
	local body
	local color
	local icon
	local app

	parse_notify_desktop "$@"

	notify_debug "${summary} ${body}"
	notify-send --urgency="${urgency}" --icon="${icon}" --app-name="${app}" "${summary}" "${body}" -h string:x-canonical-private-synchronous:"${app}" ||:
	set_xtrace
}

function notify2() {
	{ set +x; } 2>/dev/null
	local message="${1:-}"
	notify "${message}"
	notify_desktop normal "$(basename ${BASH_SOURCE[1]})" "${message}"
}

function notify_error_desktop() {
	{ set +x; } 2>/dev/null
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
	{ set +x; } 2>/dev/null
	local message=${1:-}

	notify_error_desktop "${message}"
	errexit "${message}"
}

function printline() {
	local _char=$1
	printf "%`tput cols`s" | tr " " "$_char"
}


_check_debug_logging
