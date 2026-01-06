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

#############################################################################
# State files for debouncing and race condition prevention
# Using XDG_RUNTIME_DIR for session-specific, user-specific state
# These files prevent:
# 1. Lock signal storms (unknown source sends 25 signals/sec, causing keyboard issues)
# 2. Sleep/resume race conditions (rapid PrepareForSleep 0/1 signals in same second)
#############################################################################
SWAYIDLE_STATE_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}/swayidle"
mkdir -p "$SWAYIDLE_STATE_DIR"
LOCK_DEBOUNCE_FILE="$SWAYIDLE_STATE_DIR/lock-debounce"
SLEEP_STATE_FILE="$SWAYIDLE_STATE_DIR/sleep-state"
# Debounce window in seconds - ignore lock signals within this time of last lock
LOCK_DEBOUNCE_SECONDS=2

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
	# Verify mouse was re-enabled
	if ! swaymsg -t get_inputs | grep -q '"events": "enabled"'; then
	    echo "== mouse still disabled, retrying..."
	    sleep 0.5
	    swaymsg "input type:pointer events enabled" ||:
	fi
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
	# Use wildcard first - don't rely on wlr-randr when display is off
	echo swaymsg 'output * dpms on' ||:
	swaymsg 'output * dpms on' &
	# Then handle any disabled outputs (non-blocking)
	for display in $(wlr-randr --json | jq -r .[].name ||: 2>/dev/null)
	do
		echo swaymsg "output ${display} dpms on" ||:
		swaymsg "output ${display} dpms on" &
		if [ $(wlr-randr --json | jq -r ".[] | select(.name == \"${display}\") | .enabled") = "false" ]
		then
			echo wlr-randr --output ${display} --on ||:
			wlr-randr --output ${display} --on ||:
			sleep 1
		fi
	done
}
#
#############################################################################
#
function lock() {
	# Debounce: Skip if lock was triggered recently
	# This prevents "lock signal storms" where an unknown source sends
	# ~25 lock signals/second, overwhelming the system and causing keyboard issues
	if [ -f "$LOCK_DEBOUNCE_FILE" ]; then
		local last_lock
		last_lock=$(cat "$LOCK_DEBOUNCE_FILE" 2>/dev/null || echo 0)
		local now
		now=$(date +%s)
		local elapsed=$((now - last_lock))
		if [ $elapsed -lt $LOCK_DEBOUNCE_SECONDS ]; then
			echo "=== lock (skipped - debounce, ${elapsed}s since last lock)"
			return 0
		fi
	fi

	# Skip if already locked
	if pgrep -x swaylock > /dev/null; then
		echo "=== lock (skipped - swaylock already running)"
		return 0
	fi

	# Record lock time for debouncing future calls
	date +%s > "$LOCK_DEBOUNCE_FILE"

	echo "=== lock"
	pause_notifications
	pause_mouse
	echo "= swaylock.sh"
	swaylock.sh
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
		# Clear sleep state on resume
		echo "awake" > "$SLEEP_STATE_FILE"
		resume
	elif [ "${command}" = "lock" ]
	then
		lock
	elif [ "${command}" = "unlock" ]
	then
		echo "= unlock"
		# Clear sleep state on unlock
		echo "awake" > "$SLEEP_STATE_FILE"
		resume_mouse
		resume_notifications
	elif [ "${command}" = "sleep" ]
	then
		# Prevent double-sleep from rapid PrepareForSleep signal bounces
		# (system sometimes sends wake signal immediately followed by sleep signal)
		if [ -f "$SLEEP_STATE_FILE" ] && [ "$(cat "$SLEEP_STATE_FILE" 2>/dev/null)" = "sleeping" ]; then
			echo "=== sleep (skipped - already in sleep state)"
			return 0
		fi
		echo "sleeping" > "$SLEEP_STATE_FILE"
		lock
	elif [ "${command}" = "sleepresume" ]
	then
		# Clear sleep state on sleepresume
		echo "awake" > "$SLEEP_STATE_FILE"
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
	/usr/bin/swayidle -d -C "$HOME/.config/swayidle/config" |& tee --append $HOME/logs/swayidle-$HOSTNAME-$(timestamp).log
else
	idlecommand ${command} | ts
fi
