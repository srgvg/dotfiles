#!/bin/sh
SCALE="0.9"
xrandr --output VIRTUAL1 --off
xrandr --output DP2-2 --primary --mode 3840x2160 --pos 0x0 --rotate normal --scale 1x1
xrandr --output eDP1 --mode 1920x1080 --pos 3840x1080 --rotate normal
xrandr --output DP1 --off
xrandr --output DP2-1 --off
xrandr --output DP2-3 --off
xrandr --output HDMI2 --off
xrandr --output HDMI1 --off
xrandr --output DP2-2-1 --off
xrandr --output DP2-2-8 --off
xrandr --output DP2 --off
xrandr --output DP2-2 --primary --mode 3840x2160 --pos 0x0 --rotate normal --scale ${SCALE}x${SCALE}
