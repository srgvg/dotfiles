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
# Dependencies:
# imagemagick
# swaylock
# grim
# corrupter (https://github.com/r00tman/corrupter)

IMAGES=""
PICTURE=$HOME/Pictures/Backgrounds/default/joseph-barrientos-eUMEWE-7Ewg.png
LOCK=$HOME/Documents/Pictures/icons/i3lock/lock.png
LOCKARGS="$*"

IMAGE=/tmp/lock.png
composite -gravity center $LOCK $PICTURE $IMAGE
for OUTPUT in `swaymsg -t get_outputs | jq -r '.[] | select(.active == true) | .name'`
do
    LOCKARGS="${LOCKARGS} --image ${OUTPUT}:${IMAGE}"
done
swaylock $LOCKARGS
rm $IMAGE
