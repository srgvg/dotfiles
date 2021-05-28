#!/bin/sh
xrandr --newmode "1720x1440_60.00"  209.55  1720 1848 2032 2344  1440 1441 1444 1490  -HSync +Vsync
xrandr --addmode DP2-1 "1720x1440_60.00"
xrandr --output eDP1 --mode 1600x900 --pos 120x1440 --rotate normal
xrandr --output DP1 --off
xrandr --output DP2 --off
xrandr --output DP2-1 --primary --mode 1720x1440_60.00 --pos 0x0 --rotate normal
xrandr --output DP2-2 --mode 2560x1440 --pos 1720x0 --rotate right
xrandr --output DP2-3 --off
xrandr --output HDMI1 --off
xrandr --output HDMI2 --off
xrandr --output VIRTUAL1 --off
