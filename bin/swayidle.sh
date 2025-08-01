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

echo "==== swayidle called as '$0 $*' (SWAYSOCK=$SWAYSOCK)" | ts
#
#############################################################################
#
function pause_notifications() {
	echo "== pause notifications"
	echo makoctl mode -a do-not-disturb ||:
	makoctl mode -a do-not-disturb ||:
}
function pause_mouse() {
	echo "== pause mouse"
	echo swaymsg "input type:pointer events disabled" ||:
	swaymsg "input type:pointer events disabled" ||:
}
function resume_mouse() {
	echo "== resume mouse"
	echo swaymsg "input type:pointer events enabled" ||:
	swaymsg "input type:pointer events enabled" ||:
}
function resume_notifications() {
	echo "== resume notifications"
	echo makoctl mode -r do-not-disturb ||:
	makoctl mode -r do-not-disturb ||:
	sleep 1
}
function pause_displays() {
	echo swaymsg 'output * dpms off' ||:
	swaymsg 'output * dpms off' ||:
}
function resume_displays(){
	echo "== resume displays"
	for display in $(wlr-randr --json | jq -r .[].name ||:)
	do
		echo swaymsg "output ${display} dpms on" ||:
		swaymsg "output ${display} dpms on" ||:
		if [ $(wlr-randr --json | jq -r ".[] | select(.name == \"${display}\") | .enabled") = "false" ]
		then
			echo wlr-randr --output ${display} --on ||:
			wlr-randr --output ${display} --on ||:
			sleep 1
		fi
	done
	#sleep 1
	#echo swaymsg reload ||:
	#swaymsg reload ||:
	#echo setsbg next ||:
	#setsbg next ||:
}
#
#############################################################################
#
function lock() {
	echo "=== lock"
	pause_notifications
	pause_mouse
	echo "= swaylock.sh"
	(
		swaylock.sh
		resume
	) &
}
function resume() {
	echo "=== resume"
	resume_mouse
	resume_notifications
	resume_displays
}

function idlecommand() {
	command=${1}

	if [ "${command}" = "timeout" ]
	then
		pause_displays
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
}

#
#############################################################################
#

# default start swayidle
command=${1:-default}
if [ "${command}" = "default" ]
then
	echo pkill -f "/usr/bin/swayidle"
	pkill -f "/usr/bin/swayidle" ||:
	/usr/bin/swayidle -d -w -C "$HOME/.config/swayidle/config" |& tee --append $HOME/logs/swayidle-$HOSTNAME-$(timestamp).log
else
	idlecommand ${command} | ts
fi
