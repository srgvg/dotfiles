#!/usr/bin/env bash
# vram-dpms-test.sh
#
# Tests the hypothesis (goldorak, 2026-06-24) that the swaylock VRAM "leak" is
# actually sway compositing the locked output at 60 Hz while the DISPLAY IS ON,
# and that turning DPMS OFF (no frames) stops it.
#
# Sequence (self-detaches so the launching terminal is irrelevant):
#   1. wait for lock (user presses Pause)
#   2. 120s with display ON  -> expect ~115 MiB/min climb (leak active)
#   3. swaymsg output * dpms off -> 180s -> expect FLAT (no rendering)
#   4. swaymsg output * dpms on  -> done; user unlocks
# A trap restores dpms on at any exit so the screen never stays dark.

set -u
LOG="$HOME/logs/vram-dpms-test.log"

if [ "${VRAM_DPMS_DETACHED:-0}" != "1" ]; then
    VRAM_DPMS_DETACHED=1 SWAYSOCK="${SWAYSOCK:-}" setsid "$0" "$@" >>"$LOG" 2>&1 &
    echo "detached as PID $! — log: $LOG"
    echo "Press Pause NOW to lock, walk away ~5 min, do NOT touch mouse/keys until unlock."
    exit 0
fi

sway_vram() {
    nvidia-smi pmon -c 1 -s m 2>/dev/null \
        | awk '/sway/ && $4 ~ /^[0-9]+$/ { print $4; exit }'
}
ts()   { date '+%Y-%m-%d %H:%M:%S'; }
logv() { echo "$(ts) | sway=$(sway_vram)M | $1"; }

trap 'swaymsg "output * dpms on" >/dev/null 2>&1; logv "dpms on (trap/exit)"; exit' EXIT INT TERM

echo; echo "=== dpms test — $(ts) ==="
logv "START — lock now (120s display-ON window)"

# Phase A: locked, display ON (expect leak)
for i in 1 2 3 4 5 6; do sleep 20; logv "display-ON  ($((i*20))s)"; done

# Phase B: display OFF (expect flat)
swaymsg "output * dpms off" >/dev/null 2>&1
logv "DPMS OFF — expect FLAT from here"
for i in $(seq 1 9); do sleep 20; logv "display-OFF ($((i*20))s)"; done

# Phase C: restore
swaymsg "output * dpms on" >/dev/null 2>&1
logv "DPMS ON — test done, you may UNLOCK now"
trap - EXIT INT TERM
