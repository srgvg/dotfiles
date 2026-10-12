#!/usr/bin/env bash

# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t
# vi: set shiftwidth=4 tabstop=4 noexpandtab:
# :indentSize=4:tabSize=4:noTabs=false:
#

set -o nounset
set -o errexit
set -o pipefail

monotonic_ms() {
    local uptime_seconds seconds fraction
    read -r uptime_seconds _ </proc/uptime
    seconds=${uptime_seconds%%.*}
    fraction=${uptime_seconds#*.}
    fraction="${fraction}000"
    _MONOTONIC_MS=$((10#$seconds * 1000 + 10#${fraction:0:3}))
}

_SLEEP_HANDLER_START_MS=""
if [ "${1:-}" = "sleep" ]; then
    monotonic_ms
    _SLEEP_HANDLER_START_MS=$_MONOTONIC_MS
fi

# shellcheck disable=SC1090
source "$HOME/bin/common.bash"

#############################################################################
# State files for debouncing and race condition prevention
# Using XDG_RUNTIME_DIR for session-specific, user-specific state
# These files prevent:
# 1. Lock signal storms (unknown source sends 25 signals/sec, causing keyboard issues)
# 2. Sleep/resume race conditions (rapid PrepareForSleep 0/1 signals in same second)
#############################################################################
SWAYIDLE_STATE_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}/swayidle"
mkdir -p "$SWAYIDLE_STATE_DIR"
LOCK_DEBOUNCE_FILE="$SWAYIDLE_STATE_DIR/lock-debounce"
SLEEP_STATE_FILE="$SWAYIDLE_STATE_DIR/sleep-state"
# One empty marker file per output that a modeset cycle of ours has disabled and not yet seen
# active again. resume_displays() re-enables exactly these, so an output the user disabled
# (the TV switched off by hand) stays off.
CYCLING_OUTPUTS_DIR="$SWAYIDLE_STATE_DIR/cycling-outputs"
# Debounce window in seconds - ignore lock signals within this time of last lock
LOCK_DEBOUNCE_SECONDS=2
SLEEP_HANDLER_BUDGET_MS="${SLEEP_HANDLER_BUDGET_MS:-3000}"
SLEEP_HANDLER_CLEANUP_RESERVE_MS="${SLEEP_HANDLER_CLEANUP_RESERVE_MS:-200}"
SWAYLOCK_WRAPPER="${SWAYLOCK_WRAPPER:-$HOME/bin/swaylock.sh}"
SWAYLOCK_LOG="${SWAYLOCK_LOG:-$HOME/logs/swaylock-$HOSTNAME.log}"
SWAYIDLE_BIN="${SWAYIDLE_BIN:-/usr/bin/swayidle}"
SWAYIDLE_CONFIG="${SWAYIDLE_CONFIG:-$HOME/.config/swayidle/config}"
SWAYIDLE_LOG="${SWAYIDLE_LOG:-$HOME/logs/swayidle-$HOSTNAME-$(timestamp).log}"

SNAPSHOT_LOG="$HOME/logs/nvidia-vram-snapshots.log"

# Write a timestamped EVENT line to the VRAM snapshot log.
# Usage: log_event <event_name> [detail ...]
log_event() {
    local event="$1"
    shift
    echo "$(date '+%Y-%m-%d %H:%M:%S') | EVENT | ${event}${*:+ ($*)}" >>"$SNAPSHOT_LOG"
}

# Query sway's current VRAM (MiB) from nvidia-smi pmon.
_get_sway_vram() {
    nvidia-smi pmon -c 1 -s m 2>/dev/null |
        awk '/sway/ && $4~/^[0-9]+$/{print $4;exit}'
}

_supervised_pids=()
_sleep_ready_fd=""
_sleep_ready_dir=""

_cleanup_supervised_children() {
    local pid
    for pid in "${_supervised_pids[@]}"; do
        kill "$pid" 2>/dev/null || :
    done
    for pid in "${_supervised_pids[@]}"; do
        wait "$pid" 2>/dev/null || :
    done
    _supervised_pids=()
}

_cleanup_sleep_ready() {
    if [ -n "$_sleep_ready_fd" ]; then
        exec {_sleep_ready_fd}>&-
        _sleep_ready_fd=""
    fi
    if [ -n "$_sleep_ready_dir" ]; then
        rm -f "$_sleep_ready_dir/ready"
        rmdir "$_sleep_ready_dir" 2>/dev/null || :
        _sleep_ready_dir=""
    fi
}

_swayidle_cleanup_trap() {
    _cleanup_sleep_ready
    _cleanup_supervised_children
}
trap _swayidle_cleanup_trap TERM INT

# Auto-detect SWAYSOCK if not set (needed when called from SSH/TTY rescue context)
if [ -z "${SWAYSOCK:-}" ]; then
    # Newest socket by mtime; the names are sway-ipc.<uid>.<pid>.sock, so ls is safe here.
    # shellcheck disable=SC2012
    SWAYSOCK=$(ls -t "/run/user/$(id -u)/sway-ipc."*.sock 2>/dev/null | head -1 || true)
    export SWAYSOCK
fi

echo "==== swayidle called as '$0 $*' (SWAYSOCK=$SWAYSOCK)" | ts
#
#############################################################################
#
# Mouse device to disable during lock (prevents accidental wake from sleep)
# NOTE: Don't use "type:pointer" as it disables composite keyboard/pointer devices (e.g., Keychron)
# List pointer devices with: swaymsg -t get_inputs | jq -r '.[] | select(.type == "pointer") | "\(.identifier) - \(.name)"'
MOUSE_DEVICE="1133:16507:Logitech_MX_Vertical"

# Primary output mode — used by low-res display recovery fallback.
# WARNING: do NOT use 'swaymsg reload' in recovery paths — reloading during a
# non-standard output mode causes sway/wlroots to lose all DRM outputs (confirmed 2026-04-29).
OUTPUT_MODE="7680x2160"
OUTPUT_SCALE="1.5"

function pause_notifications() {
    echo "== pause notifications"
    echo swaync-client --dnd-on --skip-wait || :
    swaync-client --dnd-on --skip-wait || :
}

swaylock_running() {
    pgrep -x swaylock >/dev/null
}

# Names of the outputs sway is driving right now. A DPMS-off output is still active; a
# disabled one is not, so the modeset cycles never touch an output the user turned off.
active_outputs() {
    local out
    out=$(swaymsg -t get_outputs -r 2>/dev/null) || return 0
    jq -r '.[] | select(.active) | .name' <<<"$out" 2>/dev/null || :
}

# Print one of: active, inactive (connected but disabled), absent, unknown (sway did not answer).
output_state() {
    local out
    out=$(swaymsg -t get_outputs -r 2>/dev/null) || {
        echo unknown
        return 0
    }
    jq -r --arg n "$1" \
        '[.[] | select(.name == $n)] | if length == 0 then "absent" elif .[0].active then "active" else "inactive" end' \
        <<<"$out" 2>/dev/null || echo unknown
}

# Modeset cycle for one output: disable, then enable. The marker exists for as long as the
# output may have been left disabled by this script.
cycle_output() {
    local display="$1"
    mkdir -p "$CYCLING_OUTPUTS_DIR"
    : >"$CYCLING_OUTPUTS_DIR/$display"
    if swaymsg output "${display}" disable; then
        sleep 1
        swaymsg output "${display}" enable || :
    fi
    if [ "$(output_state "$display")" != "active" ]; then
        sleep 1
    fi
    if [ "$(output_state "$display")" = "active" ]; then
        rm -f "$CYCLING_OUTPUTS_DIR/$display"
    else
        log_event "modeset_reenable_unconfirmed" "display=${display}"
    fi
}

function pause_mouse() {
    echo "== pause mouse"
    swaymsg "input \"${MOUSE_DEVICE}\" events disabled" || :
}
function resume_mouse() {
    echo "== resume mouse"
    swaymsg "input \"${MOUSE_DEVICE}\" events enabled" || :
    # Verify mouse was re-enabled
    if ! swaymsg -t get_inputs | jq -e ".[] | select(.identifier == \"${MOUSE_DEVICE}\") | select(.libinput.send_events == \"enabled\")" >/dev/null 2>&1; then
        echo "== mouse still disabled, retrying..."
        sleep 0.5
        swaymsg "input \"${MOUSE_DEVICE}\" events enabled" || :
    fi
}
function resume_notifications() {
    echo "== resume notifications"
    echo swaync-client --dnd-off --skip-wait || :
    swaync-client --dnd-off --skip-wait || :
    sleep 1
}
function pause_displays() {
    # Pre-DPMS modeset cycle: free Vulkan textures before GC stops running.
    # Same 85% guard as pre-lock cycle — skip if VRAM too high (cycle would fail).
    local pre_vram vram_total vram_crit
    pre_vram=$(_get_sway_vram) || pre_vram=""
    vram_total=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null || : | grep -oP '^\d+$' || : | head -1)
    vram_total=${vram_total:-8188}
    vram_crit=$((vram_total * 85 / 100))
    if [ -n "$pre_vram" ] && [ "$pre_vram" -gt "$vram_crit" ]; then
        echo "== pre-dpms: sway VRAM=${pre_vram}M > ${vram_crit}M, skipping modeset cycle" | ts
        log_event "pre_dpms_modeset_skipped" "sway=${pre_vram}M > ${vram_crit}M threshold"
    else
        echo "== pre-dpms modeset cycle (free Vulkan textures before DPMS off)" | ts
        log_event "pre_dpms_modeset" "sway=${pre_vram:-?}M"
        for display in $(active_outputs); do
            echo "== pre-dpms: disable/enable ${display}" | ts
            cycle_output "${display}"
        done
        sleep 1
        local post_vram
        post_vram=$(_get_sway_vram) || post_vram=""
        log_event "pre_dpms_modeset_done" "sway=${pre_vram:-?}M -> ${post_vram:-?}M"
    fi
    echo swaymsg 'output * dpms off' || :
    swaymsg 'output * dpms off' || :
    log_event "dpms_off"
}
function lowres_modeset_recovery() {
    # Recover display when VRAM is too high for normal modeset (NVKMS GEM alloc fails at
    # ~200 MiB needed for 7680x2160 scanout framebuffers). 1280x720 needs only ~10 MiB,
    # which succeeds even with fragmented VRAM. After dpms on at low-res, wlroots GC runs
    # and frees leaked DMA-BUF textures, then we restore the configured mode.
    # Caller must ensure swaylock is NOT running (GC only fires when background surfaces render).
    local display="$1"
    local _vram_before
    _vram_before=$(_get_sway_vram) || _vram_before=""
    # Query the display's current mode and scale before switching to low-res, so we restore
    # the correct mode for this specific output rather than the hard-coded PRIMARY defaults.
    local restore_mode restore_scale
    restore_mode=$(wlr-randr --json 2>/dev/null |
        jq -r ".[] | select(.name == \"${display}\") | .modes[] | select(.current == true) | \"\(.width)x\(.height)\"" \
            2>/dev/null || echo "")
    restore_scale=$(wlr-randr --json 2>/dev/null |
        jq -r ".[] | select(.name == \"${display}\") | .scale" \
            2>/dev/null || echo "")
    restore_mode="${restore_mode:-$OUTPUT_MODE}"
    restore_scale="${restore_scale:-$OUTPUT_SCALE}"
    echo "== low-res recovery on ${display}: 1280x720 -> ${restore_mode} scale ${restore_scale}" | ts
    log_event "lowres_recovery_start" "display=${display} sway=${_vram_before:-?}M restore=${restore_mode}@${restore_scale}"
    swaymsg "output ${display} mode 1280x720" || :
    sleep 1
    swaymsg "output ${display} dpms on" || :
    sleep 10
    swaymsg "output ${display} mode ${restore_mode} scale ${restore_scale}" || :
    local _vram_after
    _vram_after=$(_get_sway_vram) || _vram_after=""
    log_event "lowres_recovery_done" "display=${display} sway=${_vram_before:-?}M -> ${_vram_after:-?}M"
}
function resume_displays() {
    echo "== resume displays"
    # DPMS-on synchronously — must complete before modeset cycle to avoid races
    # where disable/enable fires against a DPMS-on that is still in-flight.
    echo swaymsg 'output * dpms on'
    swaymsg 'output * dpms on' || :
    sleep 1
    for display in $(active_outputs); do
        echo swaymsg "output ${display} dpms on"
        swaymsg "output ${display} dpms on" || :
    done
    # Re-enable only what a modeset cycle of ours left disabled (failed re-enable, or the
    # handler died mid-cycle). An output the user disabled has no marker and stays off.
    local marker
    for marker in "$CYCLING_OUTPUTS_DIR"/*; do
        [ -e "$marker" ] || continue
        display=${marker##*/}
        case "$(output_state "$display")" in
            inactive)
                echo wlr-randr --output "${display}" --on
                wlr-randr --output "${display}" --on || :
                sleep 1
                if [ "$(output_state "$display")" = "active" ]; then
                    rm -f "$marker"
                fi
                ;;
            active | absent)
                rm -f "$marker"
                ;;
        esac
    done
    # Force modeset cycle in background — DPMS is already on above; this works around the
    # nvidia-drm bug where DPMS on succeeds at IPC level but GPU display engine doesn't drive output.
    # At >80% VRAM the normal disable/enable cycle fails (NVKMS GEM alloc error for
    # ~200 MiB 7680x2160 scanout framebuffers) — use low-res recovery path instead.
    (sleep 3 && for display in $(active_outputs); do
        local _vram _total _crit
        _vram=$(_get_sway_vram) || _vram=""
        _total=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | grep -oP '^\d+$' | head -1)
        _total=${_total:-8188}
        _crit=$((_total * 80 / 100))
        if [ -n "$_vram" ] && [ "$_vram" -gt "$_crit" ]; then
            echo "== modeset: sway VRAM=${_vram}M > ${_crit}M — using low-res recovery" | ts
            log_event "resume_modeset_lowres" "display=${display} sway=${_vram}M > ${_crit}M threshold"
            lowres_modeset_recovery "${display}"
        else
            echo "== forcing modeset cycle on ${display}" | ts
            log_event "resume_modeset_normal" "display=${display} sway=${_vram:-?}M"
            cycle_output "${display}"
        fi
    done) &
}
#
#############################################################################
#
lock_for_sleep() {
    local handler_start_ms="$1"
    local deadline_ms=$((handler_start_ms + SLEEP_HANDLER_BUDGET_MS))
    local wrapper_pid remaining_ms read_timeout wrapper_state wrapper_rc elapsed_ms

    if swaylock_running; then
        echo "=== sleep lock (skipped - swaylock already running)"
        echo "sleeping" >"$SLEEP_STATE_FILE"
        monotonic_ms
        elapsed_ms=$((_MONOTONIC_MS - handler_start_ms))
        log_event "sleep_handler_done" "result=already_locked elapsed_ms=${elapsed_ms}"
        return 0
    fi

    echo "preparing" >"$SLEEP_STATE_FILE"
    echo "=== sleep lock"
    if ! _sleep_ready_dir=$(mktemp -d "$SWAYIDLE_STATE_DIR/lock-ready.XXXXXX"); then
        log_event "sleep_lock_failed" "reason=mktemp"
        return 1
    fi
    if ! mkfifo -m 600 "$_sleep_ready_dir/ready"; then
        _cleanup_sleep_ready
        log_event "sleep_lock_failed" "reason=mkfifo"
        return 1
    fi
    if ! exec {_sleep_ready_fd}<>"$_sleep_ready_dir/ready"; then
        _cleanup_sleep_ready
        log_event "sleep_lock_failed" "reason=open_fifo"
        return 1
    fi

    pause_notifications
    pause_mouse

    "$SWAYLOCK_WRAPPER" --cached-only --ready-fd "$_sleep_ready_fd" >>"$SWAYLOCK_LOG" 2>&1 &
    wrapper_pid=$!

    # Keep the whole handler inside three seconds, including the event-level VRAM
    # sample and pre-lock input changes. Reserve time to close and unlink the FIFO.
    monotonic_ms
    remaining_ms=$((deadline_ms - _MONOTONIC_MS - SLEEP_HANDLER_CLEANUP_RESERVE_MS))
    if [ "$remaining_ms" -gt 0 ]; then
        printf -v read_timeout '%d.%03d' "$((remaining_ms / 1000))" "$((remaining_ms % 1000))"
        if IFS= read -r -t "$read_timeout" -u "$_sleep_ready_fd"; then
            _cleanup_sleep_ready
            echo "sleeping" >"$SLEEP_STATE_FILE"
            monotonic_ms
            elapsed_ms=$((_MONOTONIC_MS - handler_start_ms))
            echo "== sleep_lock_ready elapsed_ms=${elapsed_ms}"
            log_event "sleep_lock_ready" "elapsed_ms=${elapsed_ms}"
            log_event "sleep_handler_done" "result=ready elapsed_ms=${elapsed_ms}"
            return 0
        fi
    fi

    _cleanup_sleep_ready
    wrapper_state="alive"
    wrapper_rc=""
    if ! kill -0 "$wrapper_pid" 2>/dev/null; then
        wrapper_state="exited"
        if wait "$wrapper_pid"; then
            wrapper_rc=0
        else
            wrapper_rc=$?
        fi
    fi
    monotonic_ms
    elapsed_ms=$((_MONOTONIC_MS - handler_start_ms))
    echo "== sleep_lock_timeout elapsed_ms=${elapsed_ms} wrapper=${wrapper_state}${wrapper_rc:+ rc=${wrapper_rc}}" >&2
    log_event "sleep_lock_timeout" "elapsed_ms=${elapsed_ms} wrapper=${wrapper_state}${wrapper_rc:+ rc=${wrapper_rc}}"
    log_event "sleep_handler_done" "result=timeout elapsed_ms=${elapsed_ms}"
    return 1
}

function lock() {
    # Debounce: Skip if lock was triggered recently
    # This prevents "lock signal storms" where an unknown source sends
    # ~25 lock signals/second, overwhelming the system and causing keyboard issues
    if [ -f "$LOCK_DEBOUNCE_FILE" ]; then
        local last_lock
        last_lock=$(cat "$LOCK_DEBOUNCE_FILE" 2>/dev/null || echo 0)
        local now
        now=$(date +%s)
        local elapsed=$((now - last_lock))
        if [ $elapsed -lt $LOCK_DEBOUNCE_SECONDS ]; then
            echo "=== lock (skipped - debounce, ${elapsed}s since last lock)"
            return 0
        fi
    fi

    # Skip if already locked
    if swaylock_running; then
        echo "=== lock (skipped - swaylock already running)"
        return 0
    fi

    # Record lock time for debouncing future calls
    date +%s >"$LOCK_DEBOUNCE_FILE"

    echo "=== lock"

    # Pre-lock VRAM cleanup: cycle outputs to free leaked Vulkan textures BEFORE swaylock
    # starts suppressing frame presentation (which is when wlroots GC runs).
    # Must run here — modeset cycles during swaylock are harmful (add 1-2 GiB per cycle).
    # Skip if VRAM is critically high (> 85%): at near-capacity the re-enable step will fail
    # (no VRAM for scanout framebuffers), leaving the display disabled when swaylock launches.
    # GC can't run without active rendering anyway, so the cycle is a no-op at best.
    local pre_vram
    pre_vram=$(nvidia-smi pmon -c 1 -s m 2>/dev/null |
        awk '/sway/ && $4 ~ /^[0-9]+$/ { print $4; exit }') || pre_vram=""
    local vram_total
    vram_total=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | grep -v -e Failed -e library | grep -oP '^\d+$' || : | head -1)
    vram_total=${vram_total:-8188}
    local vram_crit=$((vram_total * 85 / 100))
    if [ -n "$pre_vram" ] && [ "$pre_vram" -gt "$vram_crit" ]; then
        echo "== pre-lock: sway VRAM=${pre_vram}M > ${vram_crit}M critical, skipping modeset cycle"
        log_event "pre_lock_modeset_skipped" "sway=${pre_vram}M > ${vram_crit}M threshold"
    else
        echo "== pre-lock modeset cycle (free leaked Vulkan textures)"
        log_event "pre_lock_modeset" "sway=${pre_vram:-?}M"
        for display in $(active_outputs); do
            echo "== pre-lock: disable/enable ${display}" | ts
            cycle_output "${display}"
        done
        sleep 1
        local _post_vram
        _post_vram=$(_get_sway_vram) || _post_vram=""
        log_event "pre_lock_modeset_done" "sway=${pre_vram:-?}M -> ${_post_vram:-?}M"
    fi

    # Ensure display is on before launching swaylock — the modeset cycle could have
    # left it disabled if the re-enable step failed (e.g. VRAM just barely under threshold).
    echo "== pre-lock: ensuring displays on before swaylock"
    swaymsg 'output * dpms on' || :
    sleep 0.5

    pause_notifications
    pause_mouse
    echo "= swaylock.sh"
    swaylock.sh
}
function resume() {
    echo "=== resume"
    resume_mouse
    resume_notifications
    resume_displays
}

function idlecommand() {
    local command=${1}
    local handler_start_ms=""
    if [ "$command" = "sleep" ]; then
        if [ -n "$_SLEEP_HANDLER_START_MS" ]; then
            handler_start_ms=$_SLEEP_HANDLER_START_MS
        else
            monotonic_ms
            handler_start_ms=$_MONOTONIC_MS
        fi
    fi

    # Log event marker to VRAM snapshot log with current sway VRAM for correlation
    local _ev_vram
    _ev_vram=$(_get_sway_vram) || _ev_vram=""
    log_event "${command}" "sway=${_ev_vram:-?}M"

    if [ "${command}" = "timeout" ]; then
        pause_displays
    elif [ "${command}" = "resume" ]; then
        # Clear sleep state on resume
        echo "awake" >"$SLEEP_STATE_FILE"
        resume
    elif [ "${command}" = "lock" ]; then
        lock
    elif [ "${command}" = "unlock" ]; then
        echo "= unlock"
        # Clear sleep state on unlock
        echo "awake" >"$SLEEP_STATE_FILE"

        resume_mouse
        resume_notifications
        # Always turn DPMS back on — display may be off from idle timeout.
        # This must be unconditional: the VRAM query can return empty (slow/miss),
        # which would otherwise leave the screen permanently black.
        echo "== unlock: ensuring displays on"
        swaymsg 'output * dpms on' || :

        # Run modeset cycle to free leaked Vulkan textures if VRAM is elevated.
        # Fail-open: if the query returns empty, treat as needing cycle (safer than skipping).
        local sway_vram
        sway_vram=$(nvidia-smi pmon -c 1 -s m 2>/dev/null |
            awk '/sway/ && $4 ~ /^[0-9]+$/ { print $4; exit }') || sway_vram=""
        if [ -z "$sway_vram" ] || [ "$sway_vram" -gt 1200 ]; then
            echo "== unlock: sway VRAM=${sway_vram:-?}M, running modeset cycle"
            resume_displays
        else
            echo "== unlock: sway VRAM=${sway_vram}M <= 1200M, skipping modeset cycle"
        fi
    elif [ "${command}" = "sleep" ]; then
        # Prevent double-sleep from rapid PrepareForSleep signal bounces
        # (system sometimes sends wake signal immediately followed by sleep signal)
        if [ -f "$SLEEP_STATE_FILE" ] && [ "$(cat "$SLEEP_STATE_FILE" 2>/dev/null)" = "sleeping" ]; then
            echo "=== sleep (skipped - already in sleep state)"
            return 0
        fi
        lock_for_sleep "$handler_start_ms"
    elif [ "${command}" = "sleepresume" ]; then
        # Clear sleep state on sleepresume
        echo "awake" >"$SLEEP_STATE_FILE"
        resume
    fi
}

#
#############################################################################
#

supervise_swayidle() {
    local main_pid sleep_pid cache_pid watcher_rc

    "$SWAYLOCK_WRAPPER" --prepare-cache >>"$SWAYLOCK_LOG" 2>&1 &
    cache_pid=$!
    "$SWAYIDLE_BIN" -d -C "$SWAYIDLE_CONFIG" >>"$SWAYIDLE_LOG" 2>&1 &
    main_pid=$!
    # -C /dev/null: without it this watcher also loads $SWAYIDLE_CONFIG's default path and runs
    # every lock/unlock/resume handler a second time, concurrently with the main watcher.
    "$SWAYIDLE_BIN" -d -C /dev/null -w before-sleep "$HOME/bin/swayidle.sh sleep" >>"$SWAYIDLE_LOG" 2>&1 &
    sleep_pid=$!
    # Cache preparation is short-lived and atomic. Do not retain its PID for
    # long-term cleanup: after it exits that PID may be reused by another process.
    _supervised_pids=("$main_pid" "$sleep_pid")

    echo "== supervising swayidle main=${main_pid} sleep=${sleep_pid} cache=${cache_pid}"
    if wait -n "$main_pid" "$sleep_pid"; then
        watcher_rc=1
    else
        watcher_rc=$?
    fi
    echo "== swayidle watcher exited (status=${watcher_rc}); stopping sibling" >&2
    _cleanup_supervised_children
    return "$watcher_rc"
}

main() {
    local command=${1:-default}
    if [ "$command" = "default" ]; then
        supervise_swayidle
    elif [ "$command" = "sleep" ]; then
        # The sleep handler launches the foreground swaylock wrapper in the
        # background. Keep it out of a pipeline so this process can return to
        # swayidle as soon as the readiness handshake completes.
        idlecommand "$command"
    else
        idlecommand "$command" | ts
    fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
