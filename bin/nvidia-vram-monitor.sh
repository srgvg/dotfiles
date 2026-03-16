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

notify "Starting VRAM monitor (interval=${INTERVAL}s, warn=${WARN_PCT}%, crit=${CRIT_PCT}%)"

get_top_processes() {
    # Parse nvidia-smi pmon output, return top 3 consumers sorted by fb memory
    # Output format: name1=NNNm name2=NNNm name3=NNNm
    nvidia-smi pmon -c 1 -s m 2>/dev/null |
        awk '/^[^#]/ && $4 ~ /^[0-9]+$/ && $4 > 0 {
            name=$6; mem=$4
            # Aggregate by process name
            usage[name] += mem
        }
        END {
            # Sort by usage descending, print top 3
            n = asorti(usage, sorted, "@val_num_desc")
            for (i = 1; i <= n && i <= 3; i++) {
                printf "%s=%dM ", sorted[i], usage[sorted[i]]
            }
        }'
}

write_snapshot() {
    local ts used total pct pmon_raw
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    used=$1
    total=$2
    pct=$3

    # Get full per-process breakdown
    pmon_raw=$(nvidia-smi pmon -c 1 -s m 2>/dev/null |
        awk '/^[^#]/ && $4 ~ /^[0-9]+$/ && $4 > 0 {
            name=$6; mem=$4
            usage[name] += mem
        }
        END {
            n = asorti(usage, sorted, "@val_num_desc")
            for (i = 1; i <= n; i++) {
                printf "%s=%dM ", sorted[i], usage[sorted[i]]
            }
        }')

    echo "${ts} | ${used}/${total} MiB (${pct}%) | ${pmon_raw}" >>"${SNAPSHOT_LOG}"

    # Rotate: keep last MAX_SNAPSHOTS lines
    local lines
    lines=$(wc -l <"${SNAPSHOT_LOG}")
    if [ "${lines}" -gt "${MAX_SNAPSHOTS}" ]; then
        local excess=$((lines - TRUNC_SNAPSHOTS))
        sed -i "1,${excess}d" "${SNAPSHOT_LOG}"
    fi
}

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

    # Get top consumers for log line
    top_procs=$(get_top_processes)

    notify "VRAM: ${used}/${total} MiB (${pct}%) | Top: ${top_procs}"

    # Write snapshot to file
    write_snapshot "${used}" "${total}" "${pct}"

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
