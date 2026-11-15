# TMPDIR off tmpfs: /tmp on goldorak is tmpfs (RAM, 32 GiB, half of physical
# memory) and cannot be reclaimed once paged in, only pushed to swap. Point
# TMPDIR at disk so bare `go build`/`go test` (the Go linker honours TMPDIR,
# not GOTMPDIR), `cargo install`, and other tools that only check TMPDIR stop
# defaulting to /tmp. See ~/.claude/rules/scratch-dirs.md and
# ~/etc/docs/memory-oom.md §7. Centralised under ~/vibes beside ~/vibes/scratch
# (Serge, 2026-11-14 12:46 CET); ~/tmp drains through cronjobs.sh.
export TMPDIR="$HOME/vibes/tmp"
mkdir -p "$TMPDIR"
