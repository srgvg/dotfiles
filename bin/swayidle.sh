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

echo "=== swayidle called as $0 $* (SWAYSOCK=$SWAYSOCK)"
#
#############################################################################
#
function pause_notifications() {
	makoctl mode -a do-not-disturb ||:
}
function pause_mouse() {
	swaymsg "input type:pointer events disabled" ||:
}
function resume_mouse() {
	swaymsg "input type:pointer events enabled" ||:
}
function resume_notifications() {
	makoctl mode -r do-not-disturb ||:
	sleep 1
}
function resume_displays(){
	for display in $(wlr-randr --json | jq -r .[].name ||:)
	do
		swaymsg "output ${display} dpms on" ||:
		if [ $(wlr-randr --json | jq -r ".[] | select(.name == \"${display}\") | .enabled") = "false" ]
		then
			wlr-randr --output ${display} --on ||:
			sleep 1
		fi
	done
	sleep 1
	swaymsg reload ||:
	setsbg next ||:
}
#
#############################################################################
#
function lock() {
	pause_notifications
	swaylock.sh
}
function resume() {
	resume_mouse
	resume_notifications
	resume_displays
}

#
#############################################################################
#

# default start swayidle
command=${1:-default}
if [ "${command}" = "default" ]
then
	pkill -f "/usr/bin/swayidle -d -w -C $HOME/.config/swayidle/config" ||:
	/usr/bin/swayidle -d -w -C "$HOME/.config/swayidle/config" |& tee --append $HOME/logs/swayidle-$HOSTNAME-$(timestamp).log
elif [ "${command}" = "timeout" ]
then
	swaymsg 'output * dpms off' ||:
elif [ "${command}" = "resume" ]
then
	resume
elif [ "${command}" = "lock" ]
then
	lock
elif [ "${command}" = "unlock" ]
then
	resume_mouse
	resume_notifications
elif [ "${command}" = "sleep" ]
then
	lock
elif [ "${command}" = "sleepresume" ]
then
	resume
fi
