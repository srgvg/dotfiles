#!/bin/bash
# bridge-mcp-check-test.sh: controls for bridge-mcp-check (srgvg/claude-dotfiles#270). Fixtures only, then one read of the live tree.
# Every case names the exit code AND the verdict it expects. A case that expects 2 also checks the `why` text, so a
# crash or a wrong-reason exit 2 cannot pass for an unknown it was meant to hit. Fixtures live under TMPDIR (disk).
set -u
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
check=$here/bridge-mcp-check
work=$(mktemp -d "${TMPDIR:-$HOME/tmp}/bridge-check-test.XXXXXX") || exit 1
trap 'find "$work" -mindepth 1 -delete 2>/dev/null; rmdir "$work" 2>/dev/null' EXIT

fail=0
pass=0
shim=$work/shim-bun
printf '#!/bin/sh\nexit 0\n' >"$shim"
chmod 755 "$shim"
notexec=$work/shim-not-exec
printf '#!/bin/sh\nexit 0\n' >"$notexec"
chmod 644 "$notexec"

# link directories: linkok holds a link named bun to the working fixture shim; linkgone has no bun; linkdangling has a link to
# nothing; linknotexec has a link to a file without the execute bit. Every case below passes --link-dir ahead of its own
# arguments, so a case that names another directory overrides it.
linkok=$work/linkok; mkdir -p "$linkok"; ln -s "$shim" "$linkok/bun"
linkgone=$work/linkgone; mkdir -p "$linkgone"
linkdangling=$work/linkdangling; mkdir -p "$linkdangling"; ln -s "$work/does-not-exist" "$linkdangling/bun"
linknotexec=$work/linknotexec; mkdir -p "$linknotexec"; ln -s "$notexec" "$linknotexec/bun"

mk() { # mk <cache dir> <version> <command>
	mkdir -p "$1/$2"
	printf '{"mcpServers":{"claude_uds_bridge":{"command":"%s","args":["./dist/server.js"],"required":true}}}\n' "$3" >"$1/$2/.mcp.json"
}

run() { # run <label> <want exit> <want verdict> <want why substring or ""> -- <check args>
	local label=$1 wcode=$2 wverd=$3 wwhy=$4
	shift 5
	local out code
	out=$("$check" --marketplace-file "$work/none" --state "$work/state.$$" --link-dir "$linkok" "$@" 2>&1)
	code=$?
	if [ "$code" = "$wcode" ] && printf '%s\n' "$out" | rg -qxF "verdict: $wverd" && { [ -z "$wwhy" ] || printf '%s\n' "$out" | rg '^why: ' | rg -qF -- "$wwhy"; }; then
		pass=$((pass + 1))
		printf 'ok   %s (exit %s, %s)\n' "$label" "$code" "$wverd"
	else
		fail=$((fail + 1))
		printf 'FAIL %s: wanted exit %s %s [%s], got exit %s\n%s\n' "$label" "$wcode" "$wverd" "$wwhy" "$code" "$out"
	fi
}

vers=/home/x/.local/share/mise/installs/bun/1.4.3/bin/bun   # a path into a versioned install directory: dies on an upgrade, the link cannot help it

# 1. ok, and each lapse shape
c=$work/c1; mk "$c" 0.2.1 "$shim"
run "shim in the only version, link good" 0 ok "" -- --cache-dir "$c" --expected "$shim"
c=$work/c2; mk "$c" 0.2.1 bun
run "bare bun with the link good is ok: the link carries it" 0 ok "" -- --cache-dir "$c" --expected "$shim"
run "bare bun with no link is a lapse" 1 LAPSE "bare name bun does not run" -- --cache-dir "$c" --expected "$shim" --link-dir "$linkgone"
c=$work/c3; mk "$c" 0.2.1 "$vers"
run "absolute path into a versioned install dir is a lapse even with the link good" 1 LAPSE "neither the expected shim nor a bare bun" -- --cache-dir "$c" --expected "$shim"
c=$work/c4; mk "$c" 0.2.1 "$notexec"
run "command equals the expected shim, but that file is not executable" 1 LAPSE "not executable" -- --cache-dir "$c" --expected "$notexec"
c=$work/c4b; mk "$c" 0.2.1 "$shim"
run "a command that merely differs from a non-executable expected is a plain lapse" 1 LAPSE "neither the expected shim nor a bare bun" -- --cache-dir "$c" --expected "$notexec"

# 1b. the link, each way it fails: the patched copy does not rescue a missing link, because an update reverts the patch
c=$work/c1b; mk "$c" 0.2.1 "$shim"
run "patched copy, link missing" 1 LAPSE "bare name bun does not run" -- --cache-dir "$c" --expected "$shim" --link-dir "$linkgone"
run "patched copy, link dangling" 1 LAPSE "bare name bun does not run" -- --cache-dir "$c" --expected "$shim" --link-dir "$linkdangling"
run "patched copy, link to a file that is not executable" 1 LAPSE "bare name bun does not run" -- --cache-dir "$c" --expected "$shim" --link-dir "$linknotexec"
run "link text names the link and its target" 0 ok "" -- --cache-dir "$c" --expected "$shim"
out=$("$check" --marketplace-file "$work/none" --state "$work/state.$$" --link-dir "$linkok" --cache-dir "$c" --expected "$shim" 2>&1)
if printf '%s\n' "$out" | rg -qxF "link: $linkok/bun -> $shim"; then pass=$((pass + 1)); echo "ok   the output line names the link and where it points"; else fail=$((fail + 1)); printf 'FAIL link line\n%s\n' "$out"; fi
# the probe is the lookup of the failing launch: the bare name, on a PATH of the link directory, /usr/bin and /bin only
seen=$work/seen-path
lp=$work/linkprobe; mkdir -p "$lp"
# shellcheck disable=SC2016  # the fixture's text is written literally: $PATH must expand when the fixture runs, not now
printf '#!/bin/sh\nprintf "%%s\\n" "$PATH" >"%s"\necho 1.0.0\n' "$seen" >"$lp/bun"
chmod 755 "$lp/bun"
"$check" --marketplace-file "$work/none" --state "$work/state.$$" --link-dir "$lp" --cache-dir "$c" --expected "$shim" >/dev/null 2>&1
if [ "$(cat "$seen" 2>/dev/null)" = "$lp:/usr/bin:/bin" ]; then pass=$((pass + 1)); echo "ok   the probe runs bun by name on a PATH of the link directory, /usr/bin and /bin only"; else fail=$((fail + 1)); echo "FAIL probe PATH: $(cat "$seen" 2>&1)"; fi
# a probe cut by its own clock is unknown, never ok and never a lapse
sl=$work/linkslow; mkdir -p "$sl"
printf '#!/bin/sh\nsleep 5\n' >"$sl/bun"
chmod 755 "$sl/bun"
run "probe that does not answer in time is unknown" 2 UNKNOWN "did not answer within" -- --cache-dir "$c" --expected "$shim" --link-dir "$sl" --probe-seconds 1

# 2. the revert arrives as a NEW version directory
c=$work/c5; mk "$c" 0.2.1 "$shim"; mk "$c" 0.2.2 "$vers"
run "old version patched, NEW version a versioned path (the case the link cannot help)" 1 LAPSE "version 0.2.2" -- --cache-dir "$c" --expected "$shim"
c=$work/c5b; mk "$c" 0.2.1 "$shim"; mk "$c" 0.2.2 bun
run "old version patched, NEW version bare, link good: ok" 0 ok "" -- --cache-dir "$c" --expected "$shim"
run "old version patched, NEW version bare, link gone: lapse" 1 LAPSE "bare name bun does not run" -- --cache-dir "$c" --expected "$shim" --link-dir "$linkgone"
c=$work/c6; mk "$c" 0.2.1 "$vers"; mk "$c" 0.2.2 "$shim"
run "old version a versioned path, NEW version patched: the highest wins" 0 ok "" -- --cache-dir "$c" --expected "$shim"
c=$work/c7; mk "$c" 0.2.9 "$vers"; mk "$c" 0.2.10 "$shim"
run "0.2.10 sorts above 0.2.9 (version order, not text order)" 0 ok "" -- --cache-dir "$c" --expected "$shim"
c=$work/c8; mk "$c" 0.2.9 "$shim"; mk "$c" 0.2.10 "$vers"
run "0.2.10 a versioned path above a patched 0.2.9" 1 LAPSE "version 0.2.10" -- --cache-dir "$c" --expected "$shim"

# 3. unknown is never ok
run "no cache directory" 2 UNKNOWN "no cache directory" -- --cache-dir "$work/absent" --expected "$shim"
c=$work/c9; mkdir -p "$c"
run "empty cache directory" 2 UNKNOWN "holds no version directory" -- --cache-dir "$c" --expected "$shim"
c=$work/c10; mkdir -p "$c/0.2.1"
run "version directory without .mcp.json" 2 UNKNOWN "no readable .mcp.json" -- --cache-dir "$c" --expected "$shim"
c=$work/c11; mkdir -p "$c/0.2.1"; printf '{not json' >"$c/0.2.1/.mcp.json"
run "invalid JSON" 2 UNKNOWN "not valid JSON" -- --cache-dir "$c" --expected "$shim"
c=$work/c12; mkdir -p "$c/0.2.1"; printf '{"mcpServers":{"other":{"command":"x"}}}\n' >"$c/0.2.1/.mcp.json"
run "server absent from the file" 2 UNKNOWN "has no command" -- --cache-dir "$c" --expected "$shim"
c=$work/c13; mk "$c" 0.2.1 "$shim"
out=$(env PATH=/nonexistent "$BASH" "$check" --marketplace-file "$work/none" --state "$work/state.$$" --cache-dir "$c" --expected "$shim" 2>&1)
code=$?
if [ "$code" = 2 ] && printf '%s\n' "$out" | rg -qF "why: jq is not on PATH"; then pass=$((pass + 1)); echo "ok   jq missing (exit 2, UNKNOWN)"; else fail=$((fail + 1)); printf 'FAIL jq missing: exit %s\n%s\n' "$code" "$out"; fi
"$check" --bogus >/dev/null 2>&1
if [ $? = 64 ]; then pass=$((pass + 1)); echo "ok   a bad argument exits 64, not a reading"; else fail=$((fail + 1)); echo "FAIL a bad argument did not exit 64"; fi

# 4. the state file: written, parseable, and carries the verdict (the reader treats an old checked_at as unknown)
c=$work/c15; mk "$c" 0.2.1 "$vers"
"$check" --marketplace-file "$work/none" --state "$work/st.json" --link-dir "$linkok" --cache-dir "$c" --expected "$shim" >/dev/null 2>&1
if [ "$(jq -r .verdict "$work/st.json" 2>/dev/null)" = LAPSE ] && [ "$(jq -r .exit "$work/st.json")" = 1 ] && [ "$(jq -r '.checked_at | type' "$work/st.json")" = number ] && [ "$(jq -r .link "$work/st.json")" = "$linkok/bun -> $shim" ] && [ -z "$(find "$work" -maxdepth 1 -name 'st.json.*')" ]; then
	pass=$((pass + 1)); echo "ok   state file: LAPSE, exit 1, numeric checked_at, the link line, no temp file left"
else
	fail=$((fail + 1)); echo "FAIL state file"; cat "$work/st.json" 2>&1
fi

# 4b. the popup: raised once when the verdict crosses into not-ok, never repeated while it stands.
# The popup command is a stub that records its arguments, one line per call. The exit code never depends on it.
alog=$work/alert.log
stub=$work/alert-stub
stubfail=$work/alert-stub-fail
printf '#!/bin/sh\necho "$*" >>"%s"\nexit 0\n' "$alog" >"$stub"
printf '#!/bin/sh\necho "$*" >>"%s"\nexit 1\n' "$alog" >"$stubfail"
chmod 755 "$stub" "$stubfail"
ast=$work/alert-state.json
agood=$work/ac-good; mk "$agood" 0.2.1 "$shim"
abad=$work/ac-bad; mk "$abad" 0.2.1 "$vers"
aunk=$work/ac-absent
calls() { if [ -f "$alog" ]; then wc -l <"$alog"; else echo 0; fi; }
acase() { # acase <label> <want exit> <want total popup calls so far> <want alert> -- <check args>
	local label=$1 wcode=$2 wcalls=$3 walert=$4 out code n sa
	shift 5
	out=$("$check" --marketplace-file "$work/none" --state "$ast" --expected "$shim" --link-dir "$linkok" "$@" 2>&1)
	code=$?
	n=$(calls)
	sa=$(jq -r .alert "$ast" 2>/dev/null)
	if [ "$code" = "$wcode" ] && [ "$n" = "$wcalls" ] && [ "$sa" = "$walert" ] && printf '%s\n' "$out" | rg -qxF "alert: $walert"; then
		pass=$((pass + 1)); printf 'ok   popup: %s (exit %s, %s calls, alert=%s)\n' "$label" "$code" "$n" "$sa"
	else
		fail=$((fail + 1)); printf 'FAIL popup: %s: wanted exit %s, %s calls, alert=%s; got exit %s, %s calls, alert=%s\n%s\n' "$label" "$wcode" "$wcalls" "$walert" "$code" "$n" "$sa" "$out"
	fi
}
rm -f "$alog" "$ast"
acase "ok with no state: no popup" 0 0 none -- --cache-dir "$agood" --alert-cmd "$stub"
acase "lapse with no state: one popup" 1 1 raised -- --cache-dir "$abad" --alert-cmd "$stub"
if rg -qF -- "-u critical -a bridge-mcp-check Codex bridge plugin: LAPSE" "$alog"; then pass=$((pass + 1)); echo "ok   popup: raised with critical urgency and the verdict in the title"; else fail=$((fail + 1)); echo "FAIL popup arguments"; cat "$alog"; fi
acase "same lapse again: no second popup, alert carried" 1 1 raised -- --cache-dir "$abad" --alert-cmd "$stub"
acase "unknown while the lapse stands: no new popup" 2 1 raised -- --cache-dir "$aunk" --alert-cmd "$stub"
acase "back to ok: alert cleared" 0 1 none -- --cache-dir "$agood" --alert-cmd "$stub"
acase "lapse again after ok: a second popup" 1 2 raised -- --cache-dir "$abad" --alert-cmd "$stub"
rm -f "$ast"
acase "popup command fails: exit stays the verdict's, alert=failed" 1 3 failed -- --cache-dir "$abad" --alert-cmd "$stubfail"
acase "failed popup is retried on the next run" 1 4 failed -- --cache-dir "$abad" --alert-cmd "$stubfail"
rm -f "$ast"
acase "no --alert-cmd: nothing raised" 1 4 none -- --cache-dir "$abad"
printf '{not json' >"$ast"
acase "unreadable state counts as a crossing" 1 5 raised -- --cache-dir "$abad" --alert-cmd "$stub"
# the case bites: a copy that ignores the standing state raises on every run, so case 3 above would fail it.
# shellcheck disable=SC2016  # the single quotes are deliberate: the pattern must match the literal text `$prev_a`
sed 's/&& \[ "\$prev_a" = raised \]/\&\& false/' "$check" >"$work/mutant.every"
chmod 755 "$work/mutant.every"
rm -f "$ast"
n0=$(calls)
"$work/mutant.every" --marketplace-file "$work/none" --state "$ast" --expected "$shim" --link-dir "$linkok" --cache-dir "$abad" --alert-cmd "$stub" >/dev/null 2>&1
"$work/mutant.every" --marketplace-file "$work/none" --state "$ast" --expected "$shim" --link-dir "$linkok" --cache-dir "$abad" --alert-cmd "$stub" >/dev/null 2>&1
n1=$(calls)
if [ $((n1 - n0)) = 2 ] && ! cmp -s "$check" "$work/mutant.every"; then pass=$((pass + 1)); echo "ok   mutant 'popup on every run' raises twice on a standing lapse, so the carried-alert case would fail it"; else fail=$((fail + 1)); echo "FAIL mutant 'popup on every run' was not caught ($((n1 - n0)) calls)"; fi

# 5. the real bytes. The known-bad fingerprint is the marketplace copy's .mcp.json; the live one is the fix.
bad=$HOME/.codex/.tmp/marketplaces/leonkohli/plugins/claude-uds-bridge/.mcp.json
live=$HOME/.codex/plugins/cache/leonkohli/claude-uds-bridge
if [ -r "$bad" ]; then
	c=$work/c16; mkdir -p "$c/0.2.1"; cp "$bad" "$c/0.2.1/.mcp.json"
	run "the real marketplace bytes (a bare bun) are ok while the link is good" 0 ok "" -- --cache-dir "$c"
	run "the real marketplace bytes (a bare bun) are a lapse once the link is gone" 1 LAPSE "bare name bun does not run" -- --cache-dir "$c" --link-dir "$linkgone"
else
	echo "skip the real marketplace bytes: file not readable"
fi
# 6. the cases bite: mutants of the check must each be caught by the case built for them.
mut=$work/mutant
# shellcheck disable=SC2016  # the single quotes are deliberate: the patterns must match the literal text `$found`, `$probe_rc`
sed 's/elif \[ "\$found" != "\$expected" \] && \[ "\$found" != bun \]; then/elif false; then/' "$check" >"$mut.lapse"
sed 's/| sort -V | tail -n1)/| sort -V | head -n1)/' "$check" >"$mut.first"
# shellcheck disable=SC2016
sed 's/elif \[ "\$probe_rc" != 0 \]; then/elif false; then/' "$check" >"$mut.nolink"
# shellcheck disable=SC2016
sed 's/if \[ "\$probe_rc" = 124 \]; then/if false; then/' "$check" >"$mut.clock"
chmod 755 "$mut.lapse" "$mut.first" "$mut.nolink" "$mut.clock"
margs=(--marketplace-file "$work/none" --state "$work/m.json" --expected "$shim")
c=$work/m1; mk "$c" 0.2.1 "$vers"
if "$mut.lapse" "${margs[@]}" --link-dir "$linkok" --cache-dir "$c" >/dev/null 2>&1 && ! cmp -s "$check" "$mut.lapse"; then pass=$((pass + 1)); echo "ok   mutant 'never a lapse by command' reports ok on a versioned path, so that case would fail it"; else fail=$((fail + 1)); echo "FAIL mutant 'never a lapse by command' was not caught"; fi
c=$work/m2; mk "$c" 0.2.1 "$shim"; mk "$c" 0.2.2 "$vers"
if "$mut.first" "${margs[@]}" --link-dir "$linkok" --cache-dir "$c" >/dev/null 2>&1 && ! cmp -s "$check" "$mut.first"; then pass=$((pass + 1)); echo "ok   mutant 'judge the lowest version' reports ok on a bad new version, so the new-version case would fail it"; else fail=$((fail + 1)); echo "FAIL mutant 'judge the lowest version' was not caught"; fi
c=$work/m3; mk "$c" 0.2.1 "$shim"
if "$mut.nolink" "${margs[@]}" --link-dir "$linkgone" --cache-dir "$c" >/dev/null 2>&1 && ! cmp -s "$check" "$mut.nolink"; then pass=$((pass + 1)); echo "ok   mutant 'a failing probe is not a lapse' reports ok with the link gone, so the link cases would fail it"; else fail=$((fail + 1)); echo "FAIL mutant 'a failing probe is not a lapse' was not caught"; fi
"$mut.clock" "${margs[@]}" --link-dir "$sl" --probe-seconds 1 --cache-dir "$c" >/dev/null 2>&1
if [ $? != 2 ] && ! cmp -s "$check" "$mut.clock"; then pass=$((pass + 1)); echo "ok   mutant 'a timed-out probe is not unknown' no longer exits 2, so the unknown case would fail it"; else fail=$((fail + 1)); echo "FAIL mutant 'a timed-out probe is not unknown' was not caught"; fi

echo "--- live tree, for the record (its verdict depends on the host, not on this test):"
"$check" --marketplace-file "$bad" --state "$work/live.json" --cache-dir "$live"
echo "live exit: $?"

echo "passed $pass, failed $fail"
[ "$fail" = 0 ]
