#!/bin/sh
sed 's/export //' ~/.bashrc.d/sway.bash > ~/.config/environment.d/sway.conf
echo PATH=$PATH > ~/.config/environment.d/50-path.conf
