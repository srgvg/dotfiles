#!/usr/bin/env bash
# vram-swaylock-test.sh
#
# Final isolation (goldorak, 2026-06-24): freeze SWAYLOCK ITSELF mid-lock.
# Every Wayland *client* has been frozen with no effect, so the only renderer
# left active during lock is swaylock. If freezing it stops the ~115 MiB/min
# climb -> swaylock's rendering is the trigger (fixable via swaylock). If it
# still climbs -> pure sway/wlroots/NVIDIA renderer accumulation, no committer.
#
# Self-detaches. While swaylock is frozen you CANNOT type your PIN — wait for the
# full run; it SIGCONTs swaylock at the end (and via trap on any exit).
#
# Safety: a background watchdog force-resumes swaylock after 300s no matter what,
# so you can never get stuck locked.

set -u
LOG="$HOME/logs/vram-swaylock-test.log"
if [ "${SL_DETACHED:-0}" != "1" ]; then
    SL_DETACHED=1 setsid "$0" "$@" >>"$LOG" 2>&1 &
    echo "detached PID $! — log: $LOG"
    echo "Press Pause NOW to lock. WAIT the full ~5 min before unlocking"
    echo "(swaylock is frozen mid-test; it auto-resumes, then enter your PIN)."
    exit 0
fi

sway_vram(){ nvidia-smi pmon -c 1 -s m 2>/dev/null | awk '/sway/ && $4 ~ /^[0-9]+$/{print $4;exit}'; }
ts(){ date '+%Y-%m-%d %H:%M:%S'; }
logv(){ echo "$(ts) | sway=$(sway_vram)M | $1"; }
slpids(){ pgrep -x swaylock | tr '\n' ' '; }

# Watchdog: unconditionally resume swaylock after 300s (failsafe).
( sleep 300; pgrep -x swaylock | xargs -r kill -CONT 2>/dev/null ) &
WATCHDOG=$!

trap 'pgrep -x swaylock | xargs -r kill -CONT 2>/dev/null; kill $WATCHDOG 2>/dev/null; logv "swaylock CONT (trap/exit)"; exit' EXIT INT TERM

echo; echo "=== swaylock-freeze test — $(ts) ==="
logv "START — lock now (120s pre-stop; swaylock must be running by stop time)"
for i in 1 2 3 4 5 6; do sleep 20; logv "pre-stop  ($((i*20))s) swaylock=[$(slpids)]"; done

SL="$(slpids)"
if [ -z "$SL" ]; then
    logv "ERROR: swaylock not running — did you press Pause? aborting (nothing frozen)"
else
    # shellcheck disable=SC2086
    kill -STOP $SL 2>/dev/null
    st=""; for p in $SL; do st="$st $(awk '{print $3}' /proc/$p/stat 2>/dev/null)"; done
    logv "SIGSTOP swaylock [$SL] states:$st — expect FLAT if swaylock is the trigger"
fi

for i in $(seq 1 9); do sleep 20; logv "post-stop ($((i*20))s)"; done

# shellcheck disable=SC2086
pgrep -x swaylock | xargs -r kill -CONT 2>/dev/null
kill $WATCHDOG 2>/dev/null
logv "swaylock CONT — test done, you may UNLOCK now"
trap - EXIT INT TERM
