#!/bin/sh
xrandr --output VIRTUAL1 --off
xrandr --output DP1 --off
xrandr --output DP2 --off
xrandr --output HDMI1 --off
xrandr --output HDMI2 --off
xrandr --output DP2-1 --off
xrandr --output DP2-2 --off
xrandr --output DP2-3 --off
xrandr --output DP2-1 --primary --mode 3440x1440 --pos 0x0 --rotate normal
xrandr --output eDP1 --off
#xrandr --output DP2-2 --mode 2560x1440 --pos 3440x0 --rotate right
xrandr --output DP2-2 --mode 2560x1440 --pos 3440x0 --rotate normal
xrandr --output eDP1 --mode 1600x900 --pos 787x1440 --rotate normal
