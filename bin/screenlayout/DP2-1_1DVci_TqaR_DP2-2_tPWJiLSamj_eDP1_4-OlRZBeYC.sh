#!/bin/sh
xrandr --output eDP1 --mode 1920x1080 --pos 505x1440 --rotate normal 
xrandr --output DP1 --off 
xrandr --output DP2 --off 
xrandr --output DP2-1 --primary --mode 3440x1440 --pos 0x0 --rotate normal 
xrandr --output DP2-2 --mode 2560x1440 --pos 3440x0 --rotate right 
xrandr --output DP2-3 --off 
xrandr --output HDMI1 --off 
xrandr --output HDMI2 --off 
xrandr --output VIRTUAL1 --off
