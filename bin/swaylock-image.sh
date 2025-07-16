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
PICTURE="$(ls ${LOCK_DEFAULT_LOCKSCREEN} | head -n1)"
LOCK=$HOME/Documents/Pictures/icons/i3lock/lock.png
LOCKARGS="-c 000000"

CACHEDIR=$HOME/.cache/lock
mkdir -p $CACHEDIR
PICTURENAME=$(basename $PICTURE)
IMAGE=$CACHEDIR/${PICTURENAME%%.png}-lock.png
[ -f ${IMAGE} ] || composite -gravity center $LOCK $PICTURE $IMAGE
LOCKARGS="${LOCKARGS} --image ${IMAGE}"
#for OUTPUT in `swaymsg -t get_outputs | jq -r '.[] | select(.active == true) | .name'`
#do
#    LOCKARGS="${LOCKARGS} --image ${OUTPUT}:${IMAGE}"
#done

echo "= /usr/bin/swaylock $LOCKARGS"
/usr/bin/swaylock $LOCKARGS
