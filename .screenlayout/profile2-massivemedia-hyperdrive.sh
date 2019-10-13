#!/bin/sh
xrandr --output VIRTUAL1 --off
xrandr --output eDP1 --mode 1920x1080 --pos 1920x0 --rotate normal --scale 0.7x0.7
xrandr --output DP1 --off
xrandr --output DP2-1 --off
xrandr --output DP2-2 --primary --mode 1920x1080 --pos 0x0 --rotate normal
xrandr --output HDMI2 --off
xrandr --output HDMI1 --off
xrandr --output DP2 --off
