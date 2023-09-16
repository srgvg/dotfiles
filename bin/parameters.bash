#!/bin/bash
# shellcheck disable=SC2034

# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t
# vi: set shiftwidth=4 tabstop=4
#

HOMETMPDIRNAME="scratch"
HOMETMPDIR="$(readlink --canonicalize-missing --no-newline $HOME/$HOMETMPDIRNAME)"
BACKGROUND_PICTURES="$HOME/Pictures/Backgrounds"

DEBUG="${DEBUG:-0}"

IRC_HOST="irchost"

PA_SINK_DEFAULT_NAME="Built-in Audio"

#LOCK_ANNOTATETEXT=
LOCK_DEFAULT_LOCKSCREEN="${BACKGROUND_PICTURES}/lock/cloud-header-1509665408632.png"
LOCK_ICONS="$HOME/Pictures/icons/i3lock"
LOCK_ICON="${LOCK_ICONS}/token.png"
LOCK_SCREEN_IMAGE="$HOME/.lockscreen.png"
LOCK_SCREENSHOT_IMAGE="$HOME/.screenshot.png"

LOGS_PATH="$HOME/logs/scripts"

HOME_LAN_SUBNET="172.31.32"

SETBG_DEFAULT_BACKGROUND="${BACKGROUND_PICTURES}/default" # no trailing slash if dir
SETBG_LOOP_DELAY=${SETBG_LOOP_DELAY:-59}

SONOS_VOLUME_CACHE="$HOME/.cache/sonos-volume"



# colors
# these colors must be used with `echo -e`
# if interactive shell
if tty --silent
then
    # interactive shell
    echo_black="\033[0;30m"
    echo_red="\033[0;31m"
    echo_green="\033[0;32m"
    echo_yellow="\033[0;33m"
    echo_blue="\033[0;34m"
    echo_purple="\033[0;35m"
    echo_cyan="\033[0;36m"
    echo_white="\033[0;37;1m"
    echo_lightgray="\033[0;37m"
    echo_gray="\033[0;90m"
    echo_orange="\033[0;91m"

    echo_bold_black="\033[30;1m"
    echo_bold_red="\033[31;1m"
    echo_bold_green="\033[32;1m"
    echo_bold_yellow="\033[33;1m"
    echo_bold_blue="\033[34;1m"
    echo_bold_purple="\033[35;1m"
    echo_bold_cyan="\033[36;1m"
    echo_bold_white="\033[37;1m"
    echo_bold_orange="\033[91;1m"

    echo_underline_black="\033[30;4m"
    echo_underline_red="\033[31;4m"
    echo_underline_green="\033[32;4m"
    echo_underline_yellow="\033[33;4m"
    echo_underline_blue="\033[34;4m"
    echo_underline_purple="\033[35;4m"
    echo_underline_cyan="\033[36;4m"
    echo_underline_white="\033[37;4m"
    echo_underline_orange="\033[91;4m"

    echo_background_black="\033[40m"
    echo_background_red="\033[41m"
    echo_background_green="\033[42m"
    echo_background_yellow="\033[43m"
    echo_background_blue="\033[44m"
    echo_background_purple="\033[45m"
    echo_background_cyan="\033[46m"
    echo_background_white="\033[47;1m"
    echo_background_orange="\033[101m"

    echo_normal="\033[0m"
    echo_reset_color="\033[39m"
else
    # not interactive, no need for colors
    echo_black=""
    echo_red=""
    echo_green=""
    echo_yellow=""
    echo_blue=""
    echo_purple=""
    echo_cyan=""
    echo_white=""
    echo_lightgray=""
    echo_gray=""
    echo_orange=""

    echo_bold_black=""
    echo_bold_red=""
    echo_bold_green=""
    echo_bold_yellow=""
    echo_bold_blue=""
    echo_bold_purple=""
    echo_bold_cyan=""
    echo_bold_white=""
    echo_bold_orange=""

    echo_underline_black=""
    echo_underline_red=""
    echo_underline_green=""
    echo_underline_yellow=""
    echo_underline_blue=""
    echo_underline_purple=""
    echo_underline_cyan=""
    echo_underline_white=""
    echo_underline_orange=""

    echo_background_black=""
    echo_background_red=""
    echo_background_green=""
    echo_background_yellow=""
    echo_background_blue=""
    echo_background_purple=""
    echo_background_cyan=""
    echo_background_white=""
    echo_background_orange=""

    echo_normal=""
    echo_reset_color=""
fi

function get_colors() {
    grep echo_ "$0" | sed 's/\s*\(echo_.*\)=.*/\1/' | sort -u
}
