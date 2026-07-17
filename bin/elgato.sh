#!/usr/bin/env bash

# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t
# vi: set shiftwidth=4 tabstop=4 expandtab:
# :indentSize=4:tabSize=4:noTabs=false:

set -o nounset
set -o errexit
set -o pipefail

# shellcheck disable=SC1090
source "$HOME/bin/common.bash"

# Silence leglight's FutureWarning noise emitted on every discovery.
export PYTHONWARNINGS=ignore

# The light lives on the iot VLAN (172.31.103.0/24) with a stable DHCP
# reservation; goldorak reaches it by routed HTTP via rigel. Discovery
# (`elgato lights --discover`) uses mDNS, which returns EMPTY whenever the light
# is asleep/off-Wi-Fi and then unconditionally overwrites discovered.json with
# `[]` -- destroying the known-good address and bricking control until it is
# hand-restored. We therefore never trigger discovery from here; instead we pin
# the static address and repair the cache if it is ever missing/empty/corrupt.
ELGATO_ADDR=172.31.103.20
ELGATO_PORT=9123
ELGATO_CACHE="$HOME/.config/elgato/discovered.json"

# Ensure discovered.json holds the pinned light. Rewrites it if the file is
# missing, empty, `[]`, or not a JSON array with at least one entry. This makes
# control self-heal the moment the light is back on Wi-Fi, with no dependence on
# mDNS timing.
ensure_cache() {
    if [ -s "${ELGATO_CACHE}" ] \
        && grep -q '"address"' "${ELGATO_CACHE}" 2>/dev/null; then
        return 0
    fi
    mkdir -p "$(dirname "${ELGATO_CACHE}")"
    printf '[{"address":"%s","port":%s}]\n' \
        "${ELGATO_ADDR}" "${ELGATO_PORT}" >"${ELGATO_CACHE}"
}

###############################################################################

# No subcommand: just show the CLI usage and stop -- nothing to control,
# retry, or notify about.
if [ $# -eq 0 ]; then
    elgato
    exit $?
fi

# The Elgato Key Light drops its Wi-Fi intermittently, so a single HTTP timeout
# is expected. Make sure the cache is intact, then run the requested command; on
# failure retry quickly (re-pinning the cache in case it was wiped), then give
# up cleanly (max 3 attempts). We deliberately do NOT rediscover -- see the
# ensure_cache comment above. Output is captured so the tool's traceback/noise
# never reaches the user until we give up. An exit code of 2 is an argparse/usage
# error (bad args), not a connectivity problem -- surface it without retrying.
ensure_cache
attempt=0
while :; do
    attempt=$((attempt + 1))
    out=$(elgato "$@" 2>&1) && rc=0 || rc=$?
    if [ "${rc}" -eq 0 ]; then
        [ -n "${out}" ] && printf '%s\n' "${out}"
        break
    fi
    if [ "${rc}" -eq 2 ]; then
        printf '%s\n' "${out}" >&2
        exit "${rc}"
    fi
    if [ "${attempt}" -ge 3 ]; then
        [ -n "${out}" ] && printf '%s\n' "${out}" >&2
        echo "Error: Could not reach Elgato light" >&2
        exit 1
    fi
    # Re-pin the static address before the next attempt in case a prior run (or
    # a manual `--discover` against a sleeping light) left the cache empty.
    ensure_cache
    sleep 1
done

# Build a concise status line from a single query.
status=$(elgato lights 2>/dev/null || true)
if grep -q 'power: off' <<<"${status}"; then
    detail=$(grep 'power: off' <<<"${status}" | xargs)
else
    detail=$(grep -e brightness -e color <<<"${status}" | xargs)
fi

notify_desktop_always low "Elgato Desktop Light" "${detail}" night-light-symbolic
