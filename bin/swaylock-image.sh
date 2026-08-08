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

SWAYLOCK_BIN="${SWAYLOCK_BIN:-/usr/bin/swaylock}"
LOGINCTL_BIN="${LOGINCTL_BIN:-/usr/bin/loginctl}"
COMPOSITE_BIN="${COMPOSITE_BIN:-/usr/bin/composite}"
SWAYLOCK_CACHE_DIR="${SWAYLOCK_CACHE_DIR:-$HOME/.cache/lock}"

ready_fd=""
cached_only=0
prepare_cache_only=0
while [ "$#" -gt 0 ]; do
	case "$1" in
		--ready-fd)
			[ "$#" -ge 2 ] || { echo "Missing value for --ready-fd" >&2; exit 2; }
			ready_fd="$2"
			shift 2
			;;
		--cached-only)
			cached_only=1
			shift
			;;
		--prepare-cache)
			prepare_cache_only=1
			shift
			;;
		*)
			echo "Unknown option: $1" >&2
			exit 2
			;;
	esac
done

if [ -n "$ready_fd" ] && [[ ! "$ready_fd" =~ ^[0-9]+$ ]]; then
	echo "Invalid --ready-fd value: $ready_fd" >&2
	exit 2
fi
if [ "$prepare_cache_only" -eq 1 ] && { [ "$cached_only" -eq 1 ] || [ -n "$ready_fd" ]; }; then
	echo "--prepare-cache cannot be combined with lock options" >&2
	exit 2
fi

PICTURE="$LOCK_DEFAULT_LOCKSCREEN"
LOCK="$HOME/Documents/Pictures/icons/i3lock/lock.png"
PICTURENAME=$(basename "$PICTURE")
IMAGE="$SWAYLOCK_CACHE_DIR/${PICTURENAME%.*}-lock.png"

prepare_cache() {
	mkdir -p "$SWAYLOCK_CACHE_DIR"
	[ -f "$IMAGE" ] && return 0

	local tmp_image composite_rc
	tmp_image=$(mktemp --tmpdir="$SWAYLOCK_CACHE_DIR" --suffix=.png ".${PICTURENAME%.*}-lock.XXXXXX")
	if "$COMPOSITE_BIN" -gravity center "$LOCK" "$PICTURE" "$tmp_image"; then
		mv "$tmp_image" "$IMAGE"
	else
		composite_rc=$?
		rm -f "$tmp_image"
		return "$composite_rc"
	fi
}

if [ "$prepare_cache_only" -eq 1 ]; then
	prepare_cache
	exit 0
fi

if [ "$cached_only" -eq 0 ]; then
	if ! prepare_cache; then
		echo "=  - lock image preparation failed; using black background" >&2
	fi
fi

LOCKARGS=(-c 000000 --debug --show-failed-attempts)
if [ -f "$IMAGE" ]; then
	LOCKARGS+=(--image "$IMAGE")
fi
if [ -n "$ready_fd" ]; then
	LOCKARGS+=(--ready-fd "$ready_fd")
fi

printf '= %q' "$SWAYLOCK_BIN"
printf ' %q' "${LOCKARGS[@]}"
printf '\n'

_swaylock_exit=0
if "$SWAYLOCK_BIN" "${LOCKARGS[@]}"; then
	_swaylock_exit=0
else
	_swaylock_exit=$?
fi
echo "=  - swaylock exited (status=${_swaylock_exit})"
echo "=  - sending loginctl unlock-session"
if ! "$LOGINCTL_BIN" unlock-session; then
	echo "=  - loginctl unlock-session failed" >&2
fi
exit "$_swaylock_exit"
