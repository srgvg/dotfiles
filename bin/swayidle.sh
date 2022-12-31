#!/usr/bin/env bash

# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t
# vi: set shiftwidth=4 tabstop=4 noexpandtab:
# :indentSize=4:tabSize=4:noTabs=false:

set -o nounset
set -o errexit
set -o pipefail

# shellcheck disable=SC1090
source "$HOME/bin/common.bash"

###############################################################################

lockscreen="$HOME/bin/swaylock.sh"

swayidle -d -w \
  lock "dunstctl set-paused true"  \
  lock "$lockscreen"  \
  unlock "dunstctl set-paused false" \
  before-sleep "playerctl pause"  \
  before-sleep "${lockscreen}"  \
  before-sleep "swaymsg 'output * dpms off'"  \
  before-sleep "elgato.sh off"  \
  after-resume "swaymsg 'output * dpms on'" \
  timeout 1800 "$lockscreen"  \
  timeout 2700 "swaymsg 'output * dpms off'"  \
  idlehint 1500 \
  2>&1 | tee $HOME/logs/swayidle.log
