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

LOCK="$HOME/Documents/Pictures/icons/i3lock/lock.png"
LOCKARGS="$*"

# Create secure temp directory
TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT

for OUTPUT in $(swaymsg -t get_outputs | jq -r '.[] | select(.active == true) | .name')
do
    IMAGE="${TMPDIR}/${OUTPUT}-lock.png"
    grim -o "${OUTPUT}" "${IMAGE}"
    corrupter -mag 5 -boffset 10 -meanabber 5 "${IMAGE}" "${IMAGE}"
    composite -gravity center "${LOCK}" "${IMAGE}" "${IMAGE}"
    LOCKARGS="${LOCKARGS} --image ${OUTPUT}:${IMAGE}"
done
swaylock ${LOCKARGS}
# Cleanup handled by trap
