#!/bin/bash
# mempal-reword.sh — rewrite the mempalace Stop/PreCompact hook's
# block-reason so it explicitly directs Claude to the `mempalace:mine`
# skill instead of the ambiguous "save to your memory system" wording
# that defaults to routing saves into the built-in auto-memory.
#
# Usage: <mempalace-hook-output> | mempal-reword.sh {stop|precompact}
#
# Context: upstream `hooks_cli.py` hardcodes a harness-agnostic
# STOP_BLOCK_REASON / PRECOMPACT_BLOCK_REASON. This wrapper lives
# outside any plugin- or venv-owned path and survives both
# `uv tool upgrade mempalace` and plugin upgrades. See
# ~/.claude/projects/-home-serge/memory/mempalace.md for background.

set -euo pipefail

kind="${1:-stop}"

case "$kind" in
  stop)
    new_reason='AUTO-SAVE checkpoint for the MemPalace. Invoke the `mempalace:mine` skill now to mine this session into the palace at ~/.mempalace/palace/. Start by running `mempalace instructions mine` and follow the returned steps exactly. This is the MemPalace save path, separate from the built-in auto-memory at ~/.claude/projects/-home-serge/memory/ — keep the built-in auto-memory flow as usual, but do not substitute it for the palace save. Continue the conversation after saving.'
    ;;
  precompact)
    new_reason='COMPACTION IMMINENT — mine this entire session into the MemPalace before context is lost. Invoke the `mempalace:mine` skill now: run `mempalace instructions mine` and follow the returned steps. Be thorough; verbatim quotes where possible. The palace is at ~/.mempalace/palace/. This is in addition to any built-in auto-memory saves. Allow compaction to proceed after mining is complete.'
    ;;
  *)
    # Unknown arg — pass stdin through unchanged to avoid breaking the hook chain.
    exec cat
    ;;
esac

exec /usr/bin/jq --arg r "$new_reason" '
  if type == "object" and has("reason") then .reason = $r else . end
'
