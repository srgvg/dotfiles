#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

SCRIPT="${BASH_SOURCE[0]%/*}/swayidle.sh"

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

assert_eq() {
	local expected="$1"
	local actual="$2"
	local message="$3"
	[ "$actual" = "$expected" ] || fail "$message: expected '$expected', got '$actual'"
}

# Refuse to source the old script: its top level starts the live swayidle daemon.
rg -q '^lock_for_sleep\(\)' "$SCRIPT" || fail "lock_for_sleep is not implemented"
rg -q 'BASH_SOURCE\[0\].*\$0' "$SCRIPT" || fail "swayidle.sh has no source-safe main guard"
rg -q '^supervise_swayidle\(\)' "$SCRIPT" || fail "swayidle supervisor is not implemented"

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
mkdir -p "$TEST_DIR/runtime" "$TEST_DIR/calls"

cat > "$TEST_DIR/fake-lock" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "--prepare-cache" ]; then
	printf '%s\n' "prepare-cache" >> "$FAKE_CALLS"
	exit 0
fi
printf '%s\n' "wrapper" >> "$FAKE_CALLS"
ready_fd=""
while [ "$#" -gt 0 ]; do
	if [ "$1" = "--ready-fd" ]; then
		ready_fd="$2"
		shift 2
	else
		shift
	fi
done
printf '%s\n' "$$" > "$FAKE_WRAPPER_PID"
case "$FAKE_LOCK_MODE" in
	ready)
		printf '\n' >&"$ready_fd"
		;;
	no-ready)
		sleep 5
		;;
	fail)
		exit 23
		;;
esac
EOF
chmod +x "$TEST_DIR/fake-lock"

cat > "$TEST_DIR/fake-swayidle" <<'EOF'
#!/usr/bin/env bash
printf '%q ' "$@" >> "$FAKE_SWAYIDLE_CALLS"
printf '\n' >> "$FAKE_SWAYIDLE_CALLS"
trap 'printf "terminated\n" >> "$FAKE_SWAYIDLE_TERMINATED"; exit 0' TERM
sleep 5
EOF
chmod +x "$TEST_DIR/fake-swayidle"

export XDG_RUNTIME_DIR="$TEST_DIR/runtime"
export SWAYSOCK="$TEST_DIR/sway.sock"
export SWAYLOCK_WRAPPER="$TEST_DIR/fake-lock"
export SWAYLOCK_LOG="$TEST_DIR/calls/wrapper.log"
export SWAYIDLE_BIN="$TEST_DIR/fake-swayidle"
export SWAYIDLE_CONFIG="$TEST_DIR/swayidle.config"
export SWAYIDLE_LOG="$TEST_DIR/calls/swayidle.log"
export FAKE_SWAYIDLE_CALLS="$TEST_DIR/calls/swayidle.args"
export FAKE_SWAYIDLE_TERMINATED="$TEST_DIR/calls/swayidle.terminated"
export SLEEP_HANDLER_BUDGET_MS=300
export SLEEP_HANDLER_CLEANUP_RESERVE_MS=50
export FAKE_CALLS="$TEST_DIR/calls/order"
export FAKE_WRAPPER_PID="$TEST_DIR/calls/wrapper.pid"

# The static gate above proves the source target before this dynamic test load.
# shellcheck disable=SC1090,SC1091
source "$SCRIPT"

log_event() {
	printf 'event:%s\n' "$*" >> "$FAKE_CALLS"
}
_get_sway_vram() {
	printf '0\n'
}
pause_notifications() {
	printf 'pause-notifications\n' >> "$FAKE_CALLS"
}
pause_mouse() {
	printf 'pause-mouse\n' >> "$FAKE_CALLS"
}
clear_stale_stopped_clients() {
	printf 'clear-stale\n' >> "$FAKE_CALLS"
}
# Called indirectly by lock_for_sleep() from the sourced script.
# shellcheck disable=SC2317
swaylock_running() {
	return 1
}

FAKE_LOCK_MODE=ready
export FAKE_LOCK_MODE
monotonic_ms
start_ms=$_MONOTONIC_MS
lock_for_sleep "$start_ms"
assert_eq sleeping "$(cat "$SLEEP_STATE_FILE")" "ready sleep state"
assert_eq $'clear-stale\npause-notifications\npause-mouse\nwrapper' "$(rg -v '^event:' "$FAKE_CALLS")" "ready action order"

: > "$FAKE_CALLS"
rm -f "$SLEEP_STATE_FILE" "$FAKE_WRAPPER_PID"
FAKE_LOCK_MODE=no-ready
export FAKE_LOCK_MODE
monotonic_ms
start_ms=$_MONOTONIC_MS
set +o errexit
lock_for_sleep "$start_ms"
timeout_rc=$?
set -o errexit
[ "$timeout_rc" -ne 0 ] || fail "no-writer path succeeded"
assert_eq preparing "$(cat "$SLEEP_STATE_FILE")" "timeout sleep state"
monotonic_ms
elapsed_ms=$((_MONOTONIC_MS - start_ms))
[ "$elapsed_ms" -le 500 ] || fail "timeout exceeded test budget: ${elapsed_ms}ms"
wrapper_pid=$(cat "$FAKE_WRAPPER_PID")
kill "$wrapper_pid" 2>/dev/null ||:
wait "$wrapper_pid" 2>/dev/null ||:

: > "$FAKE_CALLS"
rm -f "$SLEEP_STATE_FILE" "$FAKE_WRAPPER_PID"
FAKE_LOCK_MODE=fail
export FAKE_LOCK_MODE
monotonic_ms
start_ms=$_MONOTONIC_MS
set +o errexit
lock_for_sleep "$start_ms"
failure_rc=$?
set -o errexit
[ "$failure_rc" -ne 0 ] || fail "failed wrapper path succeeded"
rg -q 'sleep_lock_timeout .*wrapper=exited rc=23' "$FAKE_CALLS" || fail "wrapper exit was not distinguished"

: > "$FAKE_CALLS"
echo sleeping > "$SLEEP_STATE_FILE"
swaylock_running() {
	return 0
}
monotonic_ms
start_ms=$_MONOTONIC_MS
lock_for_sleep "$start_ms"
assert_eq sleeping "$(cat "$SLEEP_STATE_FILE")" "already-locked sleep state"
if rg -v '^event:' "$FAKE_CALLS" | rg -q .; then
	fail "already-locked path changed session state"
fi

: > "$FAKE_CALLS"
: > "$FAKE_SWAYIDLE_CALLS"
"$SCRIPT" > "$TEST_DIR/calls/supervisor.log" 2>&1 &
supervisor_pid=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do
	[ "$(wc -l < "$FAKE_SWAYIDLE_CALLS")" -eq 2 ] && break
	sleep 0.05
done
assert_eq 2 "$(wc -l < "$FAKE_SWAYIDLE_CALLS")" "supervised swayidle child count"
kill "$supervisor_pid"
wait "$supervisor_pid" 2>/dev/null ||:
assert_eq 2 "$(wc -l < "$FAKE_SWAYIDLE_TERMINATED")" "terminated swayidle child count"
rg -q -- "-d -C $SWAYIDLE_CONFIG" "$FAKE_SWAYIDLE_CALLS" || fail "main watcher arguments missing"
rg -F -q -- "-d -w before-sleep /home/serge/bin/swayidle.sh\\ sleep" "$FAKE_SWAYIDLE_CALLS" || fail "sleep watcher arguments missing"
rg -q '^prepare-cache$' "$FAKE_CALLS" || fail "cache preparation was not started"

echo "PASS: swayidle sleep lock"
