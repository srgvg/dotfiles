#!/bin/bash

# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t
# vi: set shiftwidth=4 tabstop=4 noexpandtab:
# :indentSize=4:tabSize=4:noTabs=false:

set -o nounset
set -o errexit
set -o pipefail


# shellcheck disable=SC1090
source "$HOME/bin/common.bash"

inc=10
case ${1:-} in
	"up")
		action="-inc $inc"
		;;
	"down")
		action="-dec $inc"
		;;
	"set")
		action="=${2:-100}"
		;;
	*)
		echo "I don't know what you mean"
		exit 1
		;;
esac
xbacklight -time 100 $action

action2=$(echo $action | sed -e 's/-inc/increase/' -e 's/-dec/decrease/' -e 's/=/set to /')
brightness=$(xbacklight -get)
brightness=$(printf "%.0f" ${brightness})

notify-send "Brightness" "$action2" -t 1200 -i /usr/share/icons/gnome/48x48/devices/video-display.png -h int:value:$brightness -c device -u low

