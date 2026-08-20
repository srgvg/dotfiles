#!/usr/bin/env bash

# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t
# vi: set shiftwidth=4 tabstop=4 expandtab:
# :indentSize=4:tabSize=4:noTabs=false:

set -o nounset
set -o errexit
set -o pipefail

# shellcheck disable=SC1090
source "$HOME/bin/common.bash"

# Drives the Elgato Key Light via the keylightd daemon (keylightctl) instead
# of elgato.sh's direct-HTTP pyelgato path. Mirrors elgato.sh's CLI, retry
# behaviour and notification so sway keybindings are a drop-in swap. See
# ~/etc/docs/elgato.md for the two-stack background and
# ~/.claude/plans/i-used-elgato-sh-to-shimmying-sun.md for the investigation.
#
# keylightctl gaps this wrapper papers over:
#   - no `toggle`         -> read on=, invert, `light set ... on <bool>`
#   - no relative deltas  -> read current value, compute, `light set ...`
#   - `get` temperature   -> mireds, not Kelvin; `set` temperature wants Kelvin
#   - `--json`/`--waybar`/`temperature_kelvin` are always wrong (upstream
#     float64->int assertion bug) -> only the raw `-p` fields are trusted here
#   - no id fuzzy-match, and no id at all opens an interactive picker -> we
#     resolve one ourselves and always pass it explicitly
#
# elgato.sh (pyelgato, direct HTTP, no daemon) is kept on disk, unbound, as a
# manual fallback if keylightd itself is down.

MIN_BRIGHTNESS=3
MAX_BRIGHTNESS=100
MIN_KELVIN=2900
MAX_KELVIN=7000
DEFAULT_BRIGHTNESS_DELTA=10
DEFAULT_COLOR_DELTA=500

usage() {
    cat <<'EOF'
Usage: keylight.sh <command> [WHICH] [options]

  lights                                     show status
  on|off|toggle [WHICH]
  brightness [WHICH] [--level N | --brighter [D] | --dimmer [D]]
  color      [WHICH] [--level K | --warmer [D] | --cooler [D]]

Bare brightness/color (no flag) queries the current value.
EOF
}

# Clamp $1 into [$2, $3] via plain comparisons -- deliberately not `(( ))`,
# whose false/zero result is a nonzero exit status that `set -e` would treat
# as a script-ending failure.
clamp() {
    local val="$1" lo="$2" hi="$3"
    if [ "${val}" -lt "${lo}" ]; then val="${lo}"; fi
    if [ "${val}" -gt "${hi}" ]; then val="${hi}"; fi
    printf '%s\n' "${val}"
}

# Kelvin, rounded to the nearest 50 to match pyelgato's reporting granularity.
mireds_to_kelvin() {
    local mireds="$1"
    printf '%s\n' "$(( ((1000000 / mireds) + 25) / 50 * 50 ))"
}

# Print one id from `light list -p`, sorted, by index (default 0). $KEYLIGHT_ID
# overrides. Every internal pipeline is `|| true`-guarded: under
# nounset+errexit+pipefail, an assignment fed by a pipeline whose grep/sed
# finds nothing would otherwise abort the whole script, not just this call.
resolve_id() {
    local which="${1:-0}"
    if [ -n "${KEYLIGHT_ID:-}" ]; then
        printf '%s\n' "${KEYLIGHT_ID}"
        return 0
    fi
    local ids id
    ids=$(keylightctl light list -p 2>/dev/null \
        | grep -o 'id="[^"]*"' | sed 's/^id="//;s/"$//' | sort || true)
    [ -n "${ids}" ] || return 1
    id=$(printf '%s\n' "${ids}" | sed -n "$((which + 1))p" || true)
    [ -n "${id}" ] || return 1
    printf '%s\n' "${id}"
}

# keylightctl talks to the local daemon socket, not the device, so it can
# stay fast even while the light itself is unreachable -- give resolution its
# own short retry rather than folding it into the action retry below.
resolve_id_with_retry() {
    local which="$1" attempt=0 id
    while :; do
        attempt=$((attempt + 1))
        if id=$(resolve_id "${which}"); then
            printf '%s\n' "${id}"
            return 0
        fi
        [ "${attempt}" -ge 3 ] && return 1
        sleep 1
    done
}

# One state query, parsed into ON/BRIGHTNESS/MIREDS. `-p` is the only
# keylightctl output format that isn't corrupted by the float64->int bug (see
# header) -- `--json`/`--waybar`/`temperature_kelvin` are not used anywhere.
read_state() {
    local id="$1" line
    line=$(keylightctl light get "${id}" -p 2>&1) || return 1
    # Leading space anchors the key: unanchored 'on=' also matches inside
    # "firmwareversion=" (...versi-on=...), corrupting the parse.
    ON=$(grep -o ' on=[a-z]*' <<<"${line}" | tail -n1 | cut -d= -f2 || true)
    BRIGHTNESS=$(grep -o ' brightness=[0-9]*' <<<"${line}" | tail -n1 | cut -d= -f2 || true)
    MIREDS=$(grep -o ' temperature=[0-9]*' <<<"${line}" | tail -n1 | cut -d= -f2 || true)
    [ -n "${ON}" ] && [ -n "${BRIGHTNESS}" ] && [ -n "${MIREDS}" ]
}

set_brightness() {
    local id="$1" target
    read_state "${id}" || return 1
    case "${mode}" in
        level) target="${level}" ;;
        plus) target=$(( BRIGHTNESS + delta )) ;;
        minus) target=$(( BRIGHTNESS - delta )) ;;
        "") printf 'brightness: %s\n' "${BRIGHTNESS}"; return 0 ;;
    esac
    target=$(clamp "${target}" "${MIN_BRIGHTNESS}" "${MAX_BRIGHTNESS}")
    [ "${target}" -eq "${BRIGHTNESS}" ] && return 0
    keylightctl light set "${id}" brightness "${target}"
}

set_color() {
    local id="$1" cur_k target
    read_state "${id}" || return 1
    cur_k=$(mireds_to_kelvin "${MIREDS}")
    case "${mode}" in
        level) target="${level}" ;;
        plus) target=$(( cur_k + delta )) ;;
        minus) target=$(( cur_k - delta )) ;;
        "") printf 'color: %s\n' "${cur_k}"; return 0 ;;
    esac
    target=$(clamp "${target}" "${MIN_KELVIN}" "${MAX_KELVIN}")
    [ "${target}" -eq "${cur_k}" ] && return 0
    keylightctl light set "${id}" temperature "${target}"
}

# Resolve + read/set as one unit, retried together by run_with_retry -- a
# transient failure can happen at either step, same shape as elgato.sh
# re-running its whole underlying command on each attempt.
attempt_action() {
    case "${cmd}" in
        lights)
            read_state "${id}" || return 1
            local power=off kelvin
            [ "${ON}" = "true" ] && power=on
            kelvin=$(mireds_to_kelvin "${MIREDS}")
            printf 'Light %s (%s)\n  power: %s\n  brightness: %s\n  color: %sK\n' \
                "${which}" "${id}" "${power}" "${BRIGHTNESS}" "${kelvin}"
            ;;
        on) keylightctl light set "${id}" on true ;;
        off) keylightctl light set "${id}" on false ;;
        toggle)
            read_state "${id}" || return 1
            local target=true
            [ "${ON}" = "true" ] && target=false
            keylightctl light set "${id}" on "${target}"
            ;;
        brightness) set_brightness "${id}" ;;
        color) set_color "${id}" ;;
    esac
}

# The light drops Wi-Fi intermittently, so a single HTTP timeout on
# keylightd's side is expected -- retry quickly, then give up cleanly (max 3
# attempts), same shape as elgato.sh. Output is captured so noise never
# reaches the user until we give up.
run_with_retry() {
    local attempt=0 out
    while :; do
        attempt=$((attempt + 1))
        if out=$("$@" 2>&1); then
            [ -n "${out}" ] && printf '%s\n' "${out}"
            return 0
        fi
        if [ "${attempt}" -ge 3 ]; then
            [ -n "${out}" ] && printf '%s\n' "${out}" >&2
            return 1
        fi
        sleep 1
    done
}

###############################################################################

# No subcommand: usage only -- nothing to control or notify about.
if [ $# -eq 0 ]; then
    usage
    exit 2
fi

cmd="$1"; shift
case "${cmd}" in
    lights|on|off|toggle|brightness|color) ;;
    *) usage; exit 2 ;;
esac

which=0
if [ $# -gt 0 ] && [[ "$1" =~ ^[0-9]+$ ]]; then
    which="$1"; shift
fi

mode=""
level=""
delta=""
while [ $# -gt 0 ]; do
    case "$1" in
        --level)
            [ -n "${mode}" ] && { echo "Error: --level conflicts with another flag" >&2; exit 2; }
            level="${2:-}"
            [[ "${level}" =~ ^[0-9]+$ ]] || { echo "Error: --level requires a numeric value" >&2; exit 2; }
            mode=level
            shift 2
            ;;
        --brighter|--cooler)
            [ "$1" = "--brighter" ] && [ "${cmd}" != brightness ] && { echo "Error: --brighter is only valid for brightness" >&2; exit 2; }
            [ "$1" = "--cooler" ] && [ "${cmd}" != color ] && { echo "Error: --cooler is only valid for color" >&2; exit 2; }
            [ -n "${mode}" ] && { echo "Error: conflicting flags" >&2; exit 2; }
            mode=plus
            shift
            if [ $# -gt 0 ] && [[ "$1" =~ ^[0-9]+$ ]]; then delta="$1"; shift; fi
            ;;
        --dimmer|--warmer)
            [ "$1" = "--dimmer" ] && [ "${cmd}" != brightness ] && { echo "Error: --dimmer is only valid for brightness" >&2; exit 2; }
            [ "$1" = "--warmer" ] && [ "${cmd}" != color ] && { echo "Error: --warmer is only valid for color" >&2; exit 2; }
            [ -n "${mode}" ] && { echo "Error: conflicting flags" >&2; exit 2; }
            mode=minus
            shift
            if [ $# -gt 0 ] && [[ "$1" =~ ^[0-9]+$ ]]; then delta="$1"; shift; fi
            ;;
        *)
            echo "Error: unrecognised argument: $1" >&2
            exit 2
            ;;
    esac
done

if [ "${cmd}" = brightness ] && [ -z "${delta}" ]; then delta="${DEFAULT_BRIGHTNESS_DELTA}"; fi
if [ "${cmd}" = color ] && [ -z "${delta}" ]; then delta="${DEFAULT_COLOR_DELTA}"; fi

id=$(resolve_id_with_retry "${which}") || {
    echo "Error: Could not reach Elgato light" >&2
    exit 1
}

if ! run_with_retry attempt_action; then
    echo "Error: Could not reach Elgato light" >&2
    exit 1
fi

# Build a concise status line from a fresh, post-action query.
if read_state "${id}"; then
    if [ "${ON}" = "false" ]; then
        detail="power: off"
    else
        kelvin=$(mireds_to_kelvin "${MIREDS}")
        detail="brightness: ${BRIGHTNESS} color: ${kelvin}"
    fi
else
    detail="(state unknown)"
fi

notify_desktop_always low "Elgato Desktop Light" "${detail}" night-light-symbolic
