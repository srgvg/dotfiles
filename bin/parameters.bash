#!/bin/bash
# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t
# vi: set shiftwidth=4 tabstop=4
#

BACKGROUND_PICTURES="$HOME/Pictures/Backgrounds"

DEBUG="${DEBUG:-0}"

IRC_HOST="irssi_host"

PA_SINK_DEFAULT_NAME="Built-in Audio Analog Stereo"

#LOCK_ANNOTATETEXT=
LOCK_DEFAULT_LOCKSCREEN="blurred"
LOCK_ICONS="$HOME/Pictures/icons/i3lock"
LOCK_ICON="${LOCK_ICONS}/token.png"
LOCK_SCREEN_IMAGE="$HOME/.lockscreen.png"
LOCK_SCREENSHOT_IMAGE="$HOME/.screenshot.png"

LOGS_PATH="$HOME/logs/scripts"

HOME_LAN_SONOS_IP="172.31.32.197"
HOME_LAN_SUBNET="172.31.32"

SETBG_BACKGROUND="$HOME/.background.png"
SETBG_DEFAULT_BACKGROUND="${BACKGROUND_PICTURES}/default.jpg"
SETBG_LOOP_DELAY=300

SONOS_VOLUME_CACHE="$HOME/.cache/sonos-volume"

# export these where child processes need the original setting
# debug is often set interactively, so we want subprocesses to be debugged too
export DEBUG
