#!/usr/bin/env bash

# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t
# vi: set shiftwidth=4 tabstop=4 noexpandtab:
# :indentSize=4:tabSize=4:noTabs=false:
#

set -o nounset
set -o errexit
set -o pipefail

# shellcheck disable=SC1090
source "$HOME/bin/common.bash"
set -x

###############################################################################

echo "swayidle called as $0 $*"

function _lock() {
	#dunstctl set-paused true
	makoctl mode -a do-not-disturb
	swaylock.sh
}
function _resume() {
	swaymsg reload
	sleep 1
	for display in $(wlr-randr --json | jq -r .[].name)
	do
		swaymsg "output ${display} dpms on"
		if [ $(wlr-randr --json | jq -r ".[] | select(.name == \"${display}\") | .enabled") = false ]
		then
			sleep 1
			wlr-randr --output ${display} --on
		fi
	done
	sleep 1
	swaymsg reload ||:
	setsbg next ||:
	makoctl mode -r do-not-disturb ||:
}

command=${1:-default}
if [ "${command}" = "default" ]
then
	/usr/bin/swayidle -d -w -C "$HOME/.config/swayidle/config" 2>&1 | tee --append $HOME/logs/swayidle-$HOSTNAME-$(timestamp).log
elif [ "${command}" = "timeout" ]
then
	swaymsg 'output * dpms off'
elif [ "${command}" = "resume" ]
then
	_resume
elif [ "${command}" = "lock" ]
then
	_lock
elif [ "${command}" = "unlock" ]
then
	#dunstctl set-paused false
	makoctl mode -r do-not-disturb
elif [ "${command}" = "sleep" ]
then
	_lock
elif [ "${command}" = "sleepresume" ]
then
	_resume
fi
