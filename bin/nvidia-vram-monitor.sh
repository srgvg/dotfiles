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

# Automated modeset cycle: flush leaked Vulkan textures during swaylock
# wlroots 0.19.2 GC doesn't run during swaylock, causing ~115 MiB/min leak
SWAY_VRAM_MODESET_THRESHOLD="${NVIDIA_VRAM_MODESET_THRESHOLD:-3000}"  # MiB
MODESET_COOLDOWN=300  # seconds between modeset cycles
LAST_MODESET_TIME=0

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

perform_modeset_cycle() {
    # Flush leaked Vulkan textures by cycling display outputs
    local sock
    sock=$(find_swaysock)
    if [ -z "$sock" ]; then
        notify_error "modeset cycle: no SWAYSOCK found"
        return 1
    fi

    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${ts} | EVENT | modeset_cycle (sway VRAM=${1:-?}M)" >>"${SNAPSHOT_LOG}"

    notify_desktop_always normal "VRAM Remediation" \
        "Modeset cycle: flushing leaked textures (sway=${1:-?}M)"

    local output_names
    output_names=$(SWAYSOCK="$sock" swaymsg -t get_outputs 2>/dev/null |
        python3 -c "import json,sys; [print(o['name']) for o in json.load(sys.stdin) if o.get('active')]" 2>/dev/null)

    if [ -z "$output_names" ]; then
        notify_error "modeset cycle: no active outputs found"
        return 1
    fi

    for output in $output_names; do
        notify "modeset cycle: disable/enable ${output}"
        SWAYSOCK="$sock" swaymsg output "${output}" disable 2>/dev/null && \
            sleep 1 && \
            SWAYSOCK="$sock" swaymsg output "${output}" enable 2>/dev/null
    done

    LAST_MODESET_TIME=$(date +%s)

    # Verify VRAM dropped
    sleep 2
    local new_used
    new_used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')
    local new_ts
    new_ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${new_ts} | EVENT | modeset_cycle_done (VRAM now=${new_used:-?}M)" >>"${SNAPSHOT_LOG}"
    notify "modeset cycle complete (VRAM now=${new_used:-?}M)"
}

check_modeset_needed() {
    local current_sway_vram="$1"

    if [ -z "$current_sway_vram" ]; then
        return
    fi

    if [ "$current_sway_vram" -le "$SWAY_VRAM_MODESET_THRESHOLD" ]; then
        return
    fi

    # Only during swaylock (the leak only happens when swaylock suppresses rendering)
    if ! pgrep -x swaylock > /dev/null 2>&1; then
        return
    fi

    # Cooldown check
    local now
    now=$(date +%s)
    local elapsed=$((now - LAST_MODESET_TIME))
    if [ "$elapsed" -lt "$MODESET_COOLDOWN" ]; then
        return
    fi

    notify "sway VRAM ${current_sway_vram}M > threshold ${SWAY_VRAM_MODESET_THRESHOLD}M during swaylock — triggering modeset cycle"
    perform_modeset_cycle "$current_sway_vram"
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

    # Check sway VRAM growth rate and automated remediation
    sway_vram=$(extract_sway_vram "$all_procs")
    check_growth_rate "${sway_vram:-}"
    check_modeset_needed "${sway_vram:-}"

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
