#!/bin/sh
xrandr --output VIRTUAL1 --off
xrandr --output eDP1 --mode 1600x900 --pos 0x1400 --rotate normal
xrandr --output DP1 --off
xrandr --output DP2-1 --mode 2560x1440 --pos 4160x0 --rotate left
xrandr --output DP2-2 --off
xrandr --output DP2-3 --off
xrandr --output HDMI2 --off
xrandr --output HDMI1 --off
xrandr --output DP2-2-1 --off
xrandr --output DP2-2-8 --primary --mode 2560x1440 --pos 1600x500 --rotate normal
xrandr --output DP2 --off
