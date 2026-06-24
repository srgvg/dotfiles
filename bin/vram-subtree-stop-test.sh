#!/usr/bin/env bash
# vram-subtree-stop-test.sh  [pattern ...]
#
# Diagnostic for the swaylock/DPMS VRAM leak (goldorak, 2026-06-24).
# Freezes (SIGSTOP) every process matching the given command-line patterns during
# a lock, and logs sway VRAM before/after to prove whether those processes are the
# ones committing the leaking wl_buffers. Default patterns = chat/media apps.
#
# Self-detaches (setsid) so it survives even when the patterns include the foot
# terminal server it was launched from. A trap guarantees SIGCONT on any exit.
#
# USAGE: run in a terminal, then press Pause within ~10s to lock and walk away.
#        ~6 min. It auto-resumes everything at the end; unlock when done.
#
# Expected if the frozen set IS the leaker:
#   pre-stop  : sway VRAM climbs ~115 MiB/min
#   post-stop : sway VRAM goes FLAT

set -u

LOG="$HOME/logs/vram-subtree-stop-test.log"
SCRIPT_NAME="$(basename "$0")"

# Self-detach: re-exec under setsid in the background so freezing our own
# terminal (foot) does not freeze this script.
if [ "${VRAM_TEST_DETACHED:-0}" != "1" ]; then
    VRAM_TEST_DETACHED=1 setsid "$0" "$@" >>"$LOG" 2>&1 &
    echo "detached as PID $! — log: $LOG"
    echo "Press Pause NOW to lock, walk away ~6 min, unlock when log says done."
    exit 0
fi

if [ "$#" -gt 0 ]; then
    PATTERNS=( "$@" )
else
    PATTERNS=( "signal-desktop" "Signal/signal" "com.slack.Slack" "/extra/slack" \
               "mattermost" "zapzap" "ZapZap" "com.spotify" "/spotify" )
fi

collect_pids() {
    local p
    for p in "${PATTERNS[@]}"; do pgrep -f "$p"; done \
        | grep -E '^[0-9]+$' | sort -un \
        | while read -r pid; do
            # never freeze: this script, or sway/swaylock/swayidle/the monitor
            [ "$pid" = "$$" ] && continue
            local args; args=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)
            case "$args" in
                *"$SCRIPT_NAME"*) continue ;;
                *swaylock*|*swayidle*|*nvidia-vram-monitor*) continue ;;
            esac
            echo "$pid"
        done | tr '\n' ' '
}

sway_vram() {
    nvidia-smi pmon -c 1 -s m 2>/dev/null \
        | awk '/sway/ && $4 ~ /^[0-9]+$/ { print $4; exit }'
}
ts()   { date '+%Y-%m-%d %H:%M:%S'; }
logv() { echo "$(ts) | sway=$(sway_vram)M | $1"; }

PIDS="$(collect_pids)"
# shellcheck disable=SC2086
trap 'kill -CONT $PIDS 2>/dev/null; logv "SIGCONT (trap/exit)"; exit' EXIT INT TERM

echo; echo "=== freeze test [${PATTERNS[*]}] — $(ts) ==="
logv "targets: $PIDS"
logv "START — lock now (120s pre-stop window)"

for i in 1 2 3 4 5 6; do sleep 20; logv "pre-stop  ($((i*20))s locked)"; done

PIDS="$(collect_pids)"
# shellcheck disable=SC2086
kill -STOP $PIDS 2>/dev/null
logv "SIGSTOP $(echo $PIDS | wc -w) procs — expect FLAT from here"

for i in $(seq 1 12); do sleep 20; logv "post-stop ($((i*20))s)"; done

# shellcheck disable=SC2086
kill -CONT $PIDS 2>/dev/null
logv "SIGCONT — test done, you may UNLOCK now"
trap - EXIT INT TERM
