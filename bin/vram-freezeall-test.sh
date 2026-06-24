#!/usr/bin/env bash
# vram-freezeall-test.sh
#
# Decisive test (goldorak, 2026-06-24): freeze EVERY Wayland client at once
# during a lock, leaving only sway, swaylock, and core daemons running. If the
# ~115 MiB/min leak stops -> it is some client (bisect next). If it continues ->
# it is sway/swaylock/wlroots/driver internal (no client is committing).
#
# Self-detaches; logs target states to prove the freeze took; trap resumes all.

set -u
LOG="$HOME/logs/vram-freezeall-test.log"
if [ "${FA_DETACHED:-0}" != "1" ]; then
    FA_DETACHED=1 SWAYSOCK="${SWAYSOCK:-}" setsid "$0" "$@" >>"$LOG" 2>&1 &
    echo "detached PID $! — log: $LOG"
    echo "Press Pause NOW, walk away ~6 min, unlock when log says done."
    exit 0
fi

# Never freeze these (compositor, lock, this script, and daemons whose freeze
# could wedge unlock / the logger).
EXCLUDE_COMM='^(sway|swaylock|swayidle|nvidia-vram-m.*|dbus-daemon|dbus-broker|pipewire|pipewire-pulse|wireplumber|systemd|p11-kit-remote|gnome-keyring-d|polkitd|lxpolkit)$'
EXCLUDE_ARGS='vram-freezeall-test|nvidia-vram-monitor|xdg-desktop-portal'

# Flatpak/sandboxed apps reach Wayland via a socket proxy, so ss misses them.
# Union ss-discovered clients with pattern-based discovery of known apps.
APP_PATTERNS='signal-desktop|Signal/signal|com.slack.Slack|/extra/slack|mattermost|zapzap|ZapZap|com.spotify|/spotify|pwvucontrol|swaybg|msedge'

collect() {
    {
        ss -xp 2>/dev/null | grep wayland | grep -oP 'pid=\K\d+'
        pgrep -f "$APP_PATTERNS"
    } | sort -un \
    | while read -r p; do
        [ "$p" = "$$" ] && continue
        local comm args
        comm=$(ps -p "$p" -o comm= 2>/dev/null) || continue
        args=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null)
        [[ "$comm" =~ $EXCLUDE_COMM ]] && continue
        echo "$args" | grep -qE "$EXCLUDE_ARGS" && continue
        echo "$p"
    done | tr '\n' ' '
}

sway_vram(){ nvidia-smi pmon -c 1 -s m 2>/dev/null | awk '/sway/ && $4 ~ /^[0-9]+$/{print $4;exit}'; }
ts(){ date '+%Y-%m-%d %H:%M:%S'; }
logv(){ echo "$(ts) | sway=$(sway_vram)M | $1"; }

PIDS="$(collect)"
# shellcheck disable=SC2086
trap 'kill -CONT $PIDS 2>/dev/null; logv "SIGCONT (trap/exit)"; exit' EXIT INT TERM

echo; echo "=== FREEZE-ALL test — $(ts) ==="
logv "will freeze $(echo $PIDS | wc -w) wayland clients"
logv "START — lock now (120s pre-stop)"
for i in 1 2 3 4 5 6; do sleep 20; logv "pre-stop  ($((i*20))s)"; done

PIDS="$(collect)"
# shellcheck disable=SC2086
kill -STOP $PIDS 2>/dev/null
# prove the freeze: count how many are actually state T
stopped=0; for p in $PIDS; do [ "$(awk '{print $3}' /proc/$p/stat 2>/dev/null)" = "T" ] && stopped=$((stopped+1)); done
logv "SIGSTOP issued to $(echo $PIDS|wc -w) pids; $stopped now in state T — expect FLAT"

for i in $(seq 1 12); do sleep 20; logv "post-stop ($((i*20))s)"; done

# shellcheck disable=SC2086
kill -CONT $PIDS 2>/dev/null
logv "SIGCONT — test done, you may UNLOCK now"
trap - EXIT INT TERM
