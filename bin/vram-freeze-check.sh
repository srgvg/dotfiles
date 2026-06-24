#!/usr/bin/env bash
# vram-freeze-check.sh PATTERN
# Verifies that kill -STOP from a detached user-context script actually stops
# processes (state T). No lock needed. Resumes after.
set -u
LOG="$HOME/logs/vram-freeze-check.log"
if [ "${FC_DETACHED:-0}" != "1" ]; then
    FC_DETACHED=1 setsid "$0" "$@" >>"$LOG" 2>&1 &
    echo "detached PID $! — see $LOG"
    exit 0
fi
PAT="${1:-swaybg}"
state() { for p in $(pgrep -f "$PAT"); do
    [ "$p" = "$$" ] && continue
    s=$(awk '{print $3}' "/proc/$p/stat" 2>/dev/null)
    echo "  pid=$p state=$s $(tr '\0' ' ' </proc/$p/cmdline 2>/dev/null|cut -c1-40)"
  done; }
echo "=== freeze-check [$PAT] $(date '+%H:%M:%S') ==="
echo "before:"; state
PIDS=$(pgrep -f "$PAT" | grep -vE "^$$\$")
# shellcheck disable=SC2086
kill -STOP $PIDS 2>/dev/null
echo "exit code of kill -STOP: $?"
sleep 1
echo "after SIGSTOP (expect state=T):"; state
# shellcheck disable=SC2086
kill -CONT $PIDS 2>/dev/null
sleep 1
echo "after SIGCONT (expect S/R):"; state
echo "=== done ==="
