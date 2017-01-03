#!/bin/sh

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

brightness=`xbacklight -get`
brightness=$(printf "%.0f" ${brightness})

notify-send "Brightness" "$brightness" -t 300 -i xfpm-brightness-lcd -h int:value:$brightness -c device -u low

