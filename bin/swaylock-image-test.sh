#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

WRAPPER="${BASH_SOURCE[0]%/*}/swaylock-image.sh"

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

# Refuse to run the old wrapper: it hard-codes /usr/bin/swaylock and would lock
# the live session instead of using the isolated fake below.
rg -q 'SWAYLOCK_BIN' "$WRAPPER" || fail "wrapper has no SWAYLOCK_BIN test hook"
rg -q 'LOGINCTL_BIN' "$WRAPPER" || fail "wrapper has no LOGINCTL_BIN test hook"

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
FAKE_BIN="$TEST_DIR/bin"
CACHE_DIR="$TEST_DIR/cache"
CALLS_DIR="$TEST_DIR/calls"
mkdir -p "$FAKE_BIN" "$CACHE_DIR" "$CALLS_DIR"

cat > "$FAKE_BIN/swaylock" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$FAKE_CALLS_DIR/swaylock.args"
while [ "$#" -gt 0 ]; do
	if [ "$1" = "--ready-fd" ]; then
		printf '\n' >&"$2"
		shift 2
	else
		shift
	fi
done
exit "${FAKE_SWAYLOCK_EXIT:-0}"
EOF

cat > "$FAKE_BIN/loginctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_CALLS_DIR/loginctl.args"
exit "${FAKE_LOGINCTL_EXIT:-0}"
EOF

cat > "$FAKE_BIN/composite" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$FAKE_CALLS_DIR/composite.args"
output="${!#}"
: > "$output"
exit "${FAKE_COMPOSITE_EXIT:-0}"
EOF
chmod +x "$FAKE_BIN/swaylock" "$FAKE_BIN/loginctl" "$FAKE_BIN/composite"

export FAKE_CALLS_DIR="$CALLS_DIR"
export SWAYLOCK_BIN="$FAKE_BIN/swaylock"
export LOGINCTL_BIN="$FAKE_BIN/loginctl"
export COMPOSITE_BIN="$FAKE_BIN/composite"
export SWAYLOCK_CACHE_DIR="$CACHE_DIR"

set +o errexit
FAKE_SWAYLOCK_EXIT=23 "$WRAPPER" --cached-only > "$TEST_DIR/failure.log" 2>&1
wrapper_rc=$?
set -o errexit
assert_eq 23 "$wrapper_rc" "swaylock failure status"
assert_eq 1 "$(wc -l < "$CALLS_DIR/loginctl.args")" "unlock call count after failure"
assert_eq "unlock-session" "$(cat "$CALLS_DIR/loginctl.args")" "unlock command"
[ ! -e "$CALLS_DIR/composite.args" ] || fail "cached-only mode invoked ImageMagick"
if rg -q -- '--image' "$CALLS_DIR/swaylock.args"; then
	fail "cache-absent cached-only mode passed an image"
fi

rm -f "$CALLS_DIR/loginctl.args"
set +o errexit
FAKE_LOGINCTL_EXIT=19 "$WRAPPER" --cached-only > "$TEST_DIR/loginctl-failure.log" 2>&1
wrapper_rc=$?
set -o errexit
assert_eq 0 "$wrapper_rc" "loginctl failure changed swaylock success status"
assert_eq 1 "$(wc -l < "$CALLS_DIR/loginctl.args")" "failed unlock call count"

rm -f "$CALLS_DIR/loginctl.args"
fifo="$TEST_DIR/ready.fifo"
mkfifo "$fifo"
exec {ready_fd}<>"$fifo"
"$WRAPPER" --cached-only --ready-fd "$ready_fd" > "$TEST_DIR/ready.log" 2>&1 &
wrapper_pid=$!
IFS= read -r -t 1 -u "$ready_fd" || fail "readiness newline not received"
wait "$wrapper_pid"
exec {ready_fd}>&-
assert_eq 1 "$(wc -l < "$CALLS_DIR/loginctl.args")" "unlock call count after success"

rm -f "$CALLS_DIR/swaylock.args" "$CALLS_DIR/loginctl.args" "$CALLS_DIR/composite.args"
set +o errexit
FAKE_COMPOSITE_EXIT=7 "$WRAPPER" --prepare-cache > "$TEST_DIR/prepare-failure.log" 2>&1
prepare_rc=$?
set -o errexit
assert_eq 7 "$prepare_rc" "ImageMagick failure status"
[ -z "$(find "$CACHE_DIR" -type f -print -quit)" ] || fail "failed cache preparation left a file"

rm -f "$CALLS_DIR/swaylock.args" "$CALLS_DIR/loginctl.args" "$CALLS_DIR/composite.args"
set +o errexit
FAKE_COMPOSITE_EXIT=7 "$WRAPPER" > "$TEST_DIR/lock-cache-failure.log" 2>&1
wrapper_rc=$?
set -o errexit
assert_eq 0 "$wrapper_rc" "lock did not fall back after ImageMagick failure"
[ -e "$CALLS_DIR/swaylock.args" ] || fail "cache failure did not launch swaylock"
if rg -q -- '--image' "$CALLS_DIR/swaylock.args"; then
	fail "cache failure passed an incomplete image"
fi
assert_eq 1 "$(wc -l < "$CALLS_DIR/loginctl.args")" "cache-failure unlock call count"

rm -f "$CALLS_DIR/swaylock.args" "$CALLS_DIR/loginctl.args" "$CALLS_DIR/composite.args"
"$WRAPPER" --prepare-cache > "$TEST_DIR/prepare.log" 2>&1
[ -e "$CALLS_DIR/composite.args" ] || fail "prepare-cache did not invoke ImageMagick"
[ ! -e "$CALLS_DIR/swaylock.args" ] || fail "prepare-cache launched swaylock"
[ ! -e "$CALLS_DIR/loginctl.args" ] || fail "prepare-cache unlocked the session"

rm -f "$CALLS_DIR/composite.args"
"$WRAPPER" --cached-only > "$TEST_DIR/cache-hit.log" 2>&1
[ ! -e "$CALLS_DIR/composite.args" ] || fail "cached-only cache hit invoked ImageMagick"
rg -q -- '--image' "$CALLS_DIR/swaylock.args" || fail "cached image was not passed to swaylock"

echo "PASS: swaylock-image wrapper"
