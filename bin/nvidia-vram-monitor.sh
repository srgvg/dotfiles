#!/usr/bin/env bash

# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t
# vi: set shiftwidth=4 tabstop=4 expandtab:
# :indentSize=4:tabSize=4:noTabs=false:

set -o nounset
set -o errexit
set -o pipefail

# shellcheck disable=SC1090
source "$HOME/bin/common.bash"

###############################################################################

INTERVAL="${NVIDIA_VRAM_INTERVAL:-30}"
WARN_PCT="${NVIDIA_VRAM_WARN_PCT:-65}"
CRIT_PCT="${NVIDIA_VRAM_CRIT_PCT:-75}"
INTERVAL_DEFAULT="${INTERVAL}"
SNAPSHOT_LOG="$HOME/logs/nvidia-vram-snapshots.log"
MAX_SNAPSHOTS=10000
TRUNC_SNAPSHOTS=9000

# Growth rate detection: track sway's VRAM across readings
PREV_SWAY_VRAM=""
GROWTH_COUNT=0
GROWTH_THRESHOLD=100  # MiB delta per reading to count as growth
GROWTH_ALERT_COUNT=3  # consecutive readings before alerting
GROWTH_ALERTED=0      # only alert once per leak episode

# During-lock VRAM protection via SIGSTOP
# When sway VRAM exceeds threshold during swaylock, SIGSTOP non-essential GPU clients.
# This halts new wl_buffer commits, stopping texture leak accumulation.
# SIGCONT is sent by swayidle.sh unlock handler, which then runs resume_displays()
# to free the accumulated textures via modeset cycle (safe when VRAM < 92%).
# Note: SIGSTOP does NOT free existing leaked textures — it prevents further accumulation.
SWAY_VRAM_STOP_THRESHOLD="${NVIDIA_VRAM_STOP_THRESHOLD:-2000}"  # MiB
VRAM_STOPPED_PIDS_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/swayidle/vram-stopped-pids"

get_pmon_output() {
    # Parse nvidia-smi pmon output with PIDs
    # Output format: name[pid]=NNNm name[pid]=NNNm ...
    # Args: $1 = max entries (0 = all)
    local max_entries=${1:-0}
    nvidia-smi pmon -c 1 -s m 2>/dev/null |
        awk -v max="$max_entries" '/^[^#]/ && $4 ~ /^[0-9]+$/ && $4 > 0 {
            pid=$2; mem=$4; name=$6
            # Track per-PID (not aggregated by name, to show individual PIDs)
            key = name "[" pid "]"
            usage[key] += mem
        }
        END {
            n = asorti(usage, sorted, "@val_num_desc")
            limit = (max > 0 && max < n) ? max : n
            for (i = 1; i <= limit; i++) {
                printf "%s=%dM ", sorted[i], usage[sorted[i]]
            }
        }'
}

get_top_processes() {
    # Return top 3 consumers for notification line
    get_pmon_output 3
}

get_all_processes() {
    # Return all consumers for snapshot log
    get_pmon_output 0
}

extract_sway_vram() {
    # Extract sway's VRAM (MiB) from pmon output string
    # Matches sway[NNN]=NNNM pattern
    local pmon_str="$1"
    echo "$pmon_str" | grep -oP 'sway\[\d+\]=\K\d+' | head -1
}

check_growth_rate() {
    local current_sway_vram="$1"

    if [ -z "$current_sway_vram" ]; then
        return
    fi

    if [ -n "$PREV_SWAY_VRAM" ]; then
        local delta=$((current_sway_vram - PREV_SWAY_VRAM))
        if [ "$delta" -gt "$GROWTH_THRESHOLD" ]; then
            GROWTH_COUNT=$((GROWTH_COUNT + 1))
            if [ "$GROWTH_COUNT" -ge "$GROWTH_ALERT_COUNT" ] && [ "$GROWTH_ALERTED" -eq 0 ]; then
                notify_desktop_always critical "VRAM Leak Detected" \
                    "sway growing +${delta}M/reading (${GROWTH_COUNT} consecutive)"
                GROWTH_ALERTED=1
            fi
        else
            GROWTH_COUNT=0
            GROWTH_ALERTED=0
        fi
    fi

    PREV_SWAY_VRAM="$current_sway_vram"
}

find_swaysock() {
    # Find the sway IPC socket for the current user
    local uid
    uid=$(id -u)
    ls -t "/run/user/${uid}/sway-ipc."*.sock 2>/dev/null | head -1
}


check_vram_during_lock() {
    local current_sway_vram="$1"

    if [ -z "$current_sway_vram" ] || [ "$current_sway_vram" -le "$SWAY_VRAM_STOP_THRESHOLD" ]; then
        return
    fi

    # Only act during swaylock
    if ! pgrep -x swaylock > /dev/null 2>&1; then
        return
    fi

    # Only act once per lock session (state file present = already handled)
    if [ -f "$VRAM_STOPPED_PIDS_FILE" ]; then
        return
    fi

    # Find Wayland-connected processes that are likely surface submitters.
    # Two sources:
    #   1. nvidia-smi pmon: direct GPU users (alacritty, browsers using dmabuf)
    #   2. ss wayland socket: ALL Wayland clients including flatpak apps (Signal, Slack,
    #      Spotify, Mattermost — Electron apps that submit GPU-backed wl_buffers but
    #      don't appear in pmon because they go through bwrap)
    # Exclude: sway, swaylock, Xwayland, alacritty (user work), and infrastructure procs
    local pids_to_stop
    pids_to_stop=$(
    {
        # Source 1: direct GPU users from pmon
        nvidia-smi pmon -c 1 -s m 2>/dev/null |
            awk '/^[^#]/ && $4 ~ /^[0-9]+$/ && $4 > 0 { print $2 }'
        # Source 2: Wayland socket connections
        ss -xp 2>/dev/null | grep wayland | grep -oP 'pid=\K\d+'
    } | sort -u |
        while IFS= read -r pid; do
            _comm=$(ps -p "$pid" -o comm= 2>/dev/null || echo "")
            case "$_comm" in
                sway|swaylock|Xwayland|alacritty|nvidia-smi|nvidia-vram-m*) ;;
                bash|sh|tee|wl-paste|swayidle|waybar|mako|lxpolkit|wlr-randr) ;;
                atuin|gdm-wayland-ses|systemd|claude|less|git|delta|kubie) ;;
                "") ;;  # process already gone
                *) echo "$pid" ;;
            esac
        done)

    if [ -z "$pids_to_stop" ]; then
        notify_desktop_always normal "VRAM Warning" \
            "sway=${current_sway_vram}M during lock — no stoppable GPU clients found"
        # Write empty file so we don't spam this check
        touch "$VRAM_STOPPED_PIDS_FILE"
        return
    fi

    notify_desktop_always normal "VRAM Protection" \
        "Pausing GPU clients to halt leak (sway=${current_sway_vram}M). Will resume on unlock."
    notify "SIGSTOP GPU clients: $(echo "$pids_to_stop" | tr '\n' ' ')"

    # Write PIDs before stopping so unlock handler can always find them
    mkdir -p "$(dirname "$VRAM_STOPPED_PIDS_FILE")"
    echo "$pids_to_stop" > "$VRAM_STOPPED_PIDS_FILE"
    # shellcheck disable=SC2086
    kill -STOP $pids_to_stop 2>/dev/null ||:

    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${ts} | EVENT | vram_clients_stopped (sway VRAM=${current_sway_vram}M, pids=$(echo "$pids_to_stop" | tr '\n' ','))" \
        >>"${SNAPSHOT_LOG}"
}

write_snapshot() {
    local ts used total pct pmon_raw
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    used=$1
    total=$2
    pct=$3

    # Get full per-process breakdown with PIDs
    pmon_raw=$(get_all_processes)

    echo "${ts} | ${used}/${total} MiB (${pct}%) | ${pmon_raw}" >>"${SNAPSHOT_LOG}"

    # Rotate: keep last MAX_SNAPSHOTS lines
    local lines
    lines=$(wc -l <"${SNAPSHOT_LOG}")
    if [ "${lines}" -gt "${MAX_SNAPSHOTS}" ]; then
        local excess=$((lines - TRUNC_SNAPSHOTS))
        sed -i "1,${excess}d" "${SNAPSHOT_LOG}"
    fi
}

dump_snapshot() {
    read -r total used free < <(
        nvidia-smi --query-gpu=memory.total,memory.used,memory.free \
            --format=csv,noheader,nounits | tr -d ' ' | tr ',' ' '
    )

    if [ -z "${total:-}" ] || [ "${total}" -eq 0 ]; then
        echo "ERROR: nvidia-smi returned no data" >&2
        exit 1
    fi

    local pct=$((used * 100 / total))
    local pmon_raw
    pmon_raw=$(get_all_processes)

    echo "VRAM: ${used}/${total} MiB (${pct}%) | ${pmon_raw}"
    write_snapshot "${used}" "${total}" "${pct}"
    exit 0
}

# Handle --dump flag
if [ "${1:-}" = "--dump" ]; then
    dump_snapshot
fi

notify "Starting VRAM monitor (interval=${INTERVAL}s, warn=${WARN_PCT}%, crit=${CRIT_PCT}%)"

# Warn if known GPU-leak apps still have active GPU processes — their Flatpak
# devices=!dri or --disable-gpu overrides may be ineffective or not yet applied.
_leak_check=$(nvidia-smi pmon -c 1 -s m 2>/dev/null \
    | awk '$6 ~ /^(ap|signal-desktop|slack)$/ && $4~/^[0-9]+$/ && $4>50 {print $6"["$2"]="$4"M"}' \
    | tr '\n' ' ')
if [ -n "$_leak_check" ]; then
    notify_desktop_always normal "VRAM Leak Risk" \
        "GPU processes present that should be blocked: ${_leak_check} — restart affected apps"
fi

while true; do
    read -r total used free < <(
        nvidia-smi --query-gpu=memory.total,memory.used,memory.free \
            --format=csv,noheader,nounits | tr -d ' ' | tr ',' ' '
    )

    if [ -z "${total:-}" ] || [ "${total}" -eq 0 ]; then
        notify_error "nvidia-smi returned no data"
        sleep "${INTERVAL}"
        continue
    fi

    pct=$((used * 100 / total))

    # Get process info
    top_procs=$(get_top_processes)
    all_procs=$(get_all_processes)

    notify "VRAM: ${used}/${total} MiB (${pct}%) | Top: ${top_procs}"

    # Write snapshot to file (with full PID-annotated list)
    write_snapshot "${used}" "${total}" "${pct}"

    # Check sway VRAM growth rate and during-lock protection
    sway_vram=$(extract_sway_vram "$all_procs")
    check_growth_rate "${sway_vram:-}"
    check_vram_during_lock "${sway_vram:-}"

    if [ "${pct}" -ge "${CRIT_PCT}" ]; then
        notify_desktop_always critical "GPU VRAM Critical" \
            "${used}/${total} MiB (${pct}%) -- ${top_procs}-- close GPU-heavy apps"
        INTERVAL=5
    elif [ "${pct}" -ge "${WARN_PCT}" ]; then
        notify_desktop_always normal "GPU VRAM Warning" \
            "${used}/${total} MiB (${pct}%) -- ${top_procs}"
        INTERVAL=10
    else
        INTERVAL="${INTERVAL_DEFAULT}"
    fi

    sleep "${INTERVAL}"
done
