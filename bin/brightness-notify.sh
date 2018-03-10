#!/bin/bash

# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t
# vi: set shiftwidth=4 tabstop=4 noexpandtab:
# :indentSize=4:tabSize=4:noTabs=false:

set -o nounset
set -o errexit
set -o pipefail


# shellcheck disable=SC1090
source "$HOME/bin/common.bash"


case $1 in
	"up")
		xbacklight -time 100 -inc 10
		;;
	"down")
		xbacklight -time 100 -dec 10
		;;
	"set")
		xbacklight -time 100 =$2
		;;
	*)
		echo "I don't know what you mean"
		exit 1
		;;
esac

brightness=$(xbacklight -get)
brightness=$(printf "%.0f" ${brightness})

notify-send "Brightness" "$brightness" -t 800 -i xfpm-brightness-lcd -h int:value:$brightness -c device -u low

