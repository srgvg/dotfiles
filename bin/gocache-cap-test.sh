#!/usr/bin/env bash
# gocache-cap-test.sh — offline test for gocache-cap, on a fake Go build cache.
#
# Builds a throwaway cache tree with entries of known age and size and asserts
# what gocache-cap removes and keeps: entries last used over 24 h ago always
# (with Go's one-hour mtime margin), over 2 h ago only while free space is under
# the threshold and no `go` command runs, cached executables as whole
# directories, never anything outside the -a/-d entries in the two-hex-digit
# directories, never a symlink or what it points to, and nothing at all when the
# directory is a symlink, resolves elsewhere, is missing or another run holds
# the lock. Every outcome is exactly one output line. Low disk is simulated by
# raising the threshold (GOCACHE_CAP_LOW_FREE_GIB), a failing df by a stub on
# PATH, a running go command by a process with the fixture name
# GOCACHE_CAP_GO_NAME.
#
# The real cache is never touched: HOME is a fixture under $tmp and every run
# also sets GOCACHE_CAP_DIR there. CAP selects the script under test (default:
# the one beside this file). No root needed.
#
# Usage: bash gocache-cap-test.sh   (exit 0 = all pass)
set -u
export LC_ALL=C

here=$(realpath -e "$(dirname "${BASH_SOURCE[0]}")")
cap="${CAP:-$here/gocache-cap}"

tmp=$(mktemp -d) || exit 1
tmp=$(realpath -e "$tmp")
bgpid=""
trap '[ -n "$bgpid" ] && kill "$bgpid" 2>/dev/null; rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
mkdir -p "$HOME"

pass=0 fail=0
ok() { printf 'ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail + 1)); }

# entry <path> <age> <bytes>: a file of <bytes> bytes last used <age> ago.
entry() {
	mkdir -p "$(dirname "$1")"
	head -c "$3" /dev/zero >"$1"
	touch -d "-$2" "$1"
}

# fresh <dir>: a cache with entries of each age class, two cached executables
# and Go's own non-entry files, the latter all old enough to go if in scope.
fresh() {
	rm -rf "$1"
	entry "$1/00/old1-a" '30 hours' 1000
	entry "$1/ab/old2-d" '26 hours' 2000
	entry "$1/ab/edge24-d" '24 hours 30 minutes' 4000
	entry "$1/ab/mid-d" '5 hours' 8000
	entry "$1/cd/edge2-a" '2 hours 30 minutes' 16000
	entry "$1/ff/new-a" '30 minutes' 32000
	entry "$1/ee/oldexe-d/tool" '1 hour' 64000
	touch -d '-30 hours' "$1/ee/oldexe-d"
	entry "$1/ee/newexe-d/tool" '30 hours' 128
	touch -d '-30 minutes' "$1/ee/newexe-d"
	entry "$1/README" '30 days' 100
	entry "$1/trim.txt" '30 days' 10
	entry "$1/fuzz/pkg/FuzzX/corpus1" '30 days' 100
	entry "$1/zz/notentry-a" '30 days' 100
	entry "$1/00/noentrysuffix" '30 days' 100
}

# run_cap [env...]: run gocache-cap on $cache; sets $rc, $out (stdout+stderr), $lines.
run_cap() {
	out=$(env GOCACHE_CAP_DIR="$cache" GOCACHE_CAP_GO_NAME=gocapfakego "$@" bash "$cap" 2>&1)
	rc=$?
	lines=$(grep -c '' <<<"$out")
}

kept() { local f; for f in "$@"; do [ -e "$cache/$f" ] || return 1; done; }
gone() { local f; for f in "$@"; do [ ! -e "$cache/$f" ] && [ ! -L "$cache/$f" ] || return 1; done; }
always_kept=(README trim.txt fuzz/pkg/FuzzX/corpus1 zz/notentry-a 00/noentrysuffix ff/new-a ee/newexe-d/tool)

cache="$HOME/.cache/go-build"

# 1. Plenty of free space: entries last used over 24 h (+1 h margin) go,
#    including an old cached executable as a whole; one line with the bytes.
fresh "$cache"
run_cap GOCACHE_CAP_LOW_FREE_GIB=0
if [ "$rc" = 0 ] && [ "$lines" = 1 ] && gone 00/old1-a ab/old2-d ee/oldexe-d &&
	kept ab/edge24-d ab/mid-d cd/edge2-a "${always_kept[@]}" &&
	[[ "$out" == "gocache-cap: done; removed 67000 bytes"*" in 3 entries"*"free "*" GiB" ]]; then
	ok "1 normal: >25h entries and old executable removed, 24.5h kept, one line"
else
	bad "1 normal (rc=$rc lines=$lines out=$out)"
fi

# 2. Low disk, no go running: entries over 2 h (+1 h margin) go as well.
fresh "$cache"
run_cap GOCACHE_CAP_LOW_FREE_GIB=999999
if [ "$rc" = 0 ] && [ "$lines" = 1 ] && gone 00/old1-a ab/old2-d ab/edge24-d ab/mid-d ee/oldexe-d &&
	kept cd/edge2-a "${always_kept[@]}" &&
	[[ "$out" == "gocache-cap: done; removed 79000 bytes"*"under 999999 GiB free"* ]]; then
	ok "2 low disk: >3h entries removed, 2.5h and newest kept"
else
	bad "2 low disk (rc=$rc lines=$lines out=$out)"
fi

# 3. Low disk while a `go` command runs: the >2h pass is skipped. The process
#    name is a fixture one, so real go commands on the host never interfere.
mkdir -p "$tmp/gobin"
cp /usr/bin/sleep "$tmp/gobin/gocapfakego"
"$tmp/gobin/gocapfakego" 30 &
bgpid=$!
fresh "$cache"
run_cap GOCACHE_CAP_LOW_FREE_GIB=999999
kill "$bgpid" 2>/dev/null
wait "$bgpid" 2>/dev/null
bgpid=""
if [ "$rc" = 0 ] && [ "$lines" = 1 ] && gone 00/old1-a && kept ab/edge24-d ab/mid-d &&
	[[ "$out" == *"skipped while go runs"* ]]; then
	ok "3 low disk with go running: only the 24h pass runs"
else
	bad "3 low disk with go running (rc=$rc lines=$lines out=$out)"
fi

# 4. Symlinks out of the tree: an entry symlink, a symlinked entry directory
#    and a symlinked hex directory; no link and no target is touched.
fresh "$cache"
entry "$tmp/outside/victim" '30 days' 500
entry "$tmp/outside/exe/tool" '30 days' 500
entry "$tmp/outside/hex/old-a" '30 days' 500
touch -d '-30 days' "$tmp/outside/exe"
ln -s "$tmp/outside/victim" "$cache/ab/link-a"
ln -s "$tmp/outside/exe" "$cache/ab/linkexe-d"
ln -s "$tmp/outside/hex" "$cache/c1"
run_cap GOCACHE_CAP_LOW_FREE_GIB=999999
if [ "$rc" = 0 ] && [ "$lines" = 1 ] && [ -L "$cache/ab/link-a" ] && [ -L "$cache/ab/linkexe-d" ] &&
	[ -L "$cache/c1" ] && [ -f "$tmp/outside/victim" ] && [ -f "$tmp/outside/exe/tool" ] &&
	[ -f "$tmp/outside/hex/old-a" ] && gone 00/old1-a; then
	ok "4 symlinks out of the tree: links and targets kept"
else
	bad "4 symlinks out of the tree (rc=$rc lines=$lines out=$out)"
fi

# 5. The cache directory itself is a symlink: refused, target untouched.
real="$tmp/elsewhere/go-build"
fresh "$real"
rm -rf "$cache"
ln -s "$real" "$cache"
run_cap GOCACHE_CAP_LOW_FREE_GIB=999999
if [ "$rc" = 1 ] && [ "$lines" = 1 ] && [[ "$out" == *refused* ]] &&
	[ -f "$real/00/old1-a" ] && [ -f "$real/ab/mid-d" ]; then
	ok "5 cache dir is a symlink: refused, nothing removed"
else
	bad "5 cache dir is a symlink (rc=$rc lines=$lines out=$out)"
fi
rm -f "$cache"

# 6. A parent directory is a symlink, so the path resolves elsewhere: refused.
fresh "$tmp/realparent/go-build"
ln -s "$tmp/realparent" "$tmp/linkparent"
saved="$cache"
cache="$tmp/linkparent/go-build"
run_cap GOCACHE_CAP_LOW_FREE_GIB=999999
if [ "$rc" = 1 ] && [ "$lines" = 1 ] && [[ "$out" == *refused* ]] && [ -f "$tmp/realparent/go-build/00/old1-a" ]; then
	ok "6 path resolves elsewhere: refused, nothing removed"
else
	bad "6 path resolves elsewhere (rc=$rc lines=$lines out=$out)"
fi
cache="$saved"

# 7. Missing directory: exit 0, one line, creates nothing.
run_cap GOCACHE_CAP_LOW_FREE_GIB=0
if [ "$rc" = 0 ] && [ "$lines" = 1 ] && [[ "$out" == *absent* ]] && [ ! -e "$cache" ]; then
	ok "7 missing directory: exit 0, nothing created"
else
	bad "7 missing directory (rc=$rc lines=$lines out=$out)"
fi

# 8. Another run holds the lock (the cache directory): skipped, nothing removed,
#    and no lock file is created anywhere.
fresh "$cache"
exec 8<"$cache"
flock -n 8
run_cap GOCACHE_CAP_LOW_FREE_GIB=999999
exec 8<&-
if [ "$rc" = 0 ] && [ "$lines" = 1 ] && [[ "$out" == *skipped* ]] && kept 00/old1-a ab/mid-d &&
	[ -z "$(find "$tmp" -name '*lock*' -print -quit)" ]; then
	ok "8 lock held: run skipped, nothing removed"
else
	bad "8 lock held (rc=$rc lines=$lines out=$out)"
fi

# 9. Lock released: the next run proceeds.
run_cap GOCACHE_CAP_LOW_FREE_GIB=0
if [ "$rc" = 0 ] && gone 00/old1-a && kept ab/mid-d; then
	ok "9 lock released: next run proceeds"
else
	bad "9 lock released (rc=$rc lines=$lines out=$out)"
fi

# 10. df fails: exit 1, one line naming it, no low-disk pass on a guess.
fresh "$cache"
mkdir -p "$tmp/baddf"
printf '#!/bin/sh\nexit 1\n' >"$tmp/baddf/df"
chmod +x "$tmp/baddf/df"
run_cap GOCACHE_CAP_LOW_FREE_GIB=999999 PATH="$tmp/baddf:$PATH"
if [ "$rc" = 1 ] && [ "$lines" = 1 ] && [[ "$out" == *"free unknown; FAILED: df"* ]] && kept ab/mid-d; then
	ok "10 df fails: exit 1, one line, low-disk pass not run"
else
	bad "10 df fails (rc=$rc lines=$lines out=$out)"
fi

# stub <dir> < body: a PATH directory holding one bash stub named after <dir>'s
# basename, its body read from stdin.
stub() {
	mkdir -p "$1"
	{ printf '#!/bin/bash\n'; cat; } >"$1/$(basename "$1")"
	chmod +x "$1/$(basename "$1")"
}

# 11. The find that lists executable directories fails: exit 1, one line.
fresh "$cache"
stub "$tmp/stubs/find" <<'EOF'
case " $* " in *" -print0 "*) /usr/bin/find "$@"; exit 1 ;; esac
exec /usr/bin/find "$@"
EOF
run_cap GOCACHE_CAP_LOW_FREE_GIB=0 PATH="$tmp/stubs/find:$PATH"
if [ "$rc" = 1 ] && [ "$lines" = 1 ] && [[ "$out" == *"FAILED: find (executables"* ]]; then
	ok "11 executable listing fails: exit 1, one line"
else
	bad "11 executable listing fails (rc=$rc lines=$lines out=$out)"
fi

# 12. flock itself errors (not contention): exit 1, one line, nothing removed.
fresh "$cache"
stub "$tmp/stubs/flock" <<'EOF'
echo "flock: simulated error" >&2
exit 64
EOF
run_cap GOCACHE_CAP_LOW_FREE_GIB=0 PATH="$tmp/stubs/flock:$PATH"
if [ "$rc" = 1 ] && [ "$lines" = 1 ] && [[ "$out" == *"lock failed"* ]] && kept 00/old1-a; then
	ok "12 flock error: exit 1, one line, nothing removed"
else
	bad "12 flock error (rc=$rc lines=$lines out=$out)"
fi

# 12b. The cache directory can be entered but not opened for reading (mode
#      0300), so the lock cannot be taken: exit 1, one line, nothing removed.
fresh "$cache"
chmod 0300 "$cache"
run_cap GOCACHE_CAP_LOW_FREE_GIB=0
chmod 0755 "$cache"
if [ "$rc" = 1 ] && [ "$lines" = 1 ] && [[ "$out" == *"cannot open"*"for locking"* ]] && kept 00/old1-a; then
	ok "12b lock fd cannot be opened: exit 1, one line, nothing removed"
else
	bad "12b lock fd cannot be opened (rc=$rc lines=$lines out=$out)"
fi

# 13. An old executable directory on another filesystem (stat reports another
#     device; a real mount needs root): its contents are kept, exit 1.
fresh "$cache"
entry "$cache/ee/mnt-d/tool" '30 hours' 100
touch -d '-30 hours' "$cache/ee/mnt-d"
stub "$tmp/stubs/stat" <<'EOF'
case "${*: -1}" in *mnt-d) echo 999999 ;; *) exec /usr/bin/stat "$@" ;; esac
EOF
run_cap GOCACHE_CAP_LOW_FREE_GIB=0 PATH="$tmp/stubs/stat:$PATH"
if [ "$rc" = 1 ] && [ "$lines" = 1 ] && kept ee/mnt-d/tool && gone ee/oldexe-d &&
	[[ "$out" == *"other filesystem at ./ee/mnt-d"* ]]; then
	ok "13 executable dir on another filesystem: kept, exit 1"
else
	bad "13 executable dir on another filesystem (rc=$rc lines=$lines out=$out)"
fi

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
