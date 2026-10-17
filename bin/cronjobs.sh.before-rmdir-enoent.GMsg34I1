#!/usr/bin/env bash

# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t
# vi: set shiftwidth=4 tabstop=4 expandtab:
# :indentSize=4:tabSize=4:noTabs=false:

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -o nounset
set -o errexit
#set -o pipefail

# shellcheck disable=SC1090
source "$HOME/bin/common.bash"

#######################################################################################################################
#
# Single dispatcher: one action name in $1, one action runs, output goes to
# ~/logs/cronjobs/<host>-<action>-<YYMMDDHH>.log. Under cron the run stays silent unless it
# fails (see the on_exit trap at the tail of this file) -- a healthy run must produce no stdout.
#
# Schedules live OUTSIDE this file -- this script only implements what each action does, not
# when. Sources, one row per action:
#
#   action              trigger              schedule                      defined in
#   ------------------  -------------------  ----------------------------  --------------------------------------------
#   picwide             user crontab         daily 12:30                  crontab -l (mirrored to ~/etc/config/crontab
#                                                                          by the hostname=goldorak block at the tail
#                                                                          of this file)
#   cleanup             user crontab         hourly at :00                crontab -l
#   backup              user crontab         every 2 h at :30             crontab -l (branch below is a no-op)
#   nah-stall-report    user crontab         Mondays 07:00                crontab -l
#   update-tools        systemd user timer   01,05,09,13,17,21:15         ~/.config/systemd/user/update-tools.timer
#   firefoxpwa-relink   systemd user timer   02,06,10,14,18,22:35         ~/.config/systemd/user/firefoxpwa-relink.timer
#   etc-drift           none                 manual only -- not currently scheduled (see the
#                                             branch below and ~/etc/docs/etc-config-mirror.md)
#
# Both systemd units run `%h/bin/cronjobs.sh <action>`, so their timers route through this file
# too, not just crontab.
#
#######################################################################################################################

command=${1:-default}

LOGDIR="${HOME}/logs/cronjobs"
LOGFILE="${LOGDIR}/$(hostname)-${command}-$(date +%y%m%d%H).log"

# Run from a terminal, or from cron? Under cron, anything this script puts on stdout
# becomes an email, so a healthy run must stay silent -- see the tail of this file.
if [ -t 1 ]; then INTERACTIVE=yes; else INTERACTIVE=no; fi

#######################################################################################################################

function log() {
    mkdir -p "$(dirname "${LOGFILE}")"
    if [ "${INTERACTIVE}" = "yes" ]; then
        # Interactive: stream to the terminal as well, so a manual run is watchable.
        tee --append "${LOGFILE}"
    else
        # Under cron: file only. The caller re-emits this on failure.
        cat >>"${LOGFILE}"
    fi
    # delete file if empty
    test -s "${LOGFILE}" || rm "${LOGFILE}"
}

function scan() {
    # Best-effort housekeeping scan.
    #
    # nice/ionice: this runs hourly in the background, it must never compete with
    # interactive work.
    #
    # `|| true`: the trees swept below are live temp dirs -- a go-link or gcc temp
    # directory routinely disappears between find's readdir and its stat, and find
    # then exits non-zero after printing "No such file or directory". `common.bash`
    # turns on `pipefail` (overriding the disabled `set -o pipefail` at the top of
    # this file), so without this that race aborts the entire cleanup run under
    # errexit. Swallowing find's status is safe here: the consuming `xargs` is last
    # in every pipeline, so a genuine rm/rmdir failure is still caught.
    nice -n 20 ionice -c 3 find "$@" || true
}

function logline() {
    echo "# $*"
}
function logtitle() {
    echo
    echo "### $*"
    echo
}

#######################################################################################################################

function execute() {
    local command
    command=${1:-default}

    ###############################################################################
    # Trigger: user crontab, hourly at :00.
    #
    # ${tempfolders} = ~/scratch/{clips,temp,tmp,t}  ~/tmp  ~/logs  ~/logs/cronjobs
    #
    # Full retention policy, one row per sweep below (locations, what each removes, the age
    # threshold, and the find/rm action taken):
    #
    #   location                              what                          older than   action
    #   -------------------------------------  ----------------------------  -----------  ------------
    #   ~/scratch, ~/tmp        (top level)    files + symlinks                 48 h       rm
    #   ${tempfolders}          (recursive)    files + symlinks                 48 h       rm
    #   ${tempfolders}          (depth >= 2)   empty dirs                       -          rmdir
    #   ~/tmp                   (depth 1)      empty go-build work dirs         48 h       rmdir
    #   ~/scratch/.stfolder                    syncthing marker dir             -          recreate
    #   ~/core.*                               Edge crash dumps                 -          rm
    #   ~/logs                  (recursive)    log files                        8 d        rm
    #   ~/.claude/todos                        *.json                          30 d        rm
    #   ~/.claude/shell-snapshots              snapshot-*.sh                    7 d        rm
    #   ~/.claude/reviews                      *.md.log                        30 d        rm
    #   ~/.claude/file-history  (depth 1)      per-session dirs                30 d        rm -r
    #   ~/.claude/jobs          (depth 1)      g*-loop job dirs                30 d        rm -r
    #   ~/.claude/gates-state                  dryrun-* witness markers         2 h        rm
    #   ~/.claude/debug         (depth 1)      debug dumps                     30 d        rm -r
    #   ~/.claude                              settings*.json.bak*             90 d        rm
    #   ~/.local/share/claude/versions         superseded binaries (not the    30 d        rm
    #                                          ~/.local/bin/claude target)
    #   ~/.config/nah/nah.log.1                rotated nah decision log         -          archive (copy)
    #   ~/.local/state/nah-log                 archived nah logs               60 d        rm
    #   ~/.claude/reviews/*/state              abandoned g*-loop states       1 h past      mark done
    #                                                                         deadline
    #
    # note: ~/logs and ~/logs/cronjobs are also members of ${tempfolders}, so the 48 h sweep
    # already removes log files -- the dedicated 8-day ~/logs prune further below is subsumed
    # by it. Likewise ~/tmp is swept both by the top-level block and by the ${tempfolders} loop.
    # Both are pre-existing overlaps, documented here, not changed.
    if [ "${command}" = "cleanup" ]; then

        cleantime="+2880" # 48 hours
        tempfolders="$HOME/scratch/clips $HOME/scratch/temp $HOME/scratch/tmp $HOME/scratch/t $HOME/tmp/ $HOME/logs $HOME/logs/cronjobs"

        # cleanup files:
        # ~/scratch and ~/tmp, top level only (maxdepth 1): files and symlinks idle > 48 h.
        # (subdirectories of these two are handled by the ${tempfolders} loop below)
        logtitle Looking for files in ~/scratch itself
        scan \
            $HOME/scratch/ \
            $HOME/tmp/ \
            -maxdepth 1 \
            -not -path '/home/serge/scratch/.stfolder' \
            -not -path '/home/serge/scratch/.stignore' \
            -mmin ${cleantime} \( -type f -o -type l \) \
            -print0 | xargs -r -0 rm -fv

        # ${tempfolders} recursively: files and symlinks idle > 48 h.
        logtitle looking for files in temp folders
        for folder in ${tempfolders}; do
            if [ -d ${folder} ]; then
                logtitle "=== ${folder} ==="
                scan \
                    ${folder} \
                    -depth -mindepth 1 \
                    -mmin ${cleantime} \( -type f -o -type l \) \
                    -print0 | xargs -r -0 rm -fv
            fi
        done

        # ${tempfolders} at depth >= 2: any now-empty directory left behind by the file sweep
        # above, regardless of age.
        logtitle looking for empty dirs in temp folders
        for folder in ${tempfolders}; do
            if [ -d ${folder} ]; then
                scan \
                    ${folder} \
                    -depth -mindepth 2 \
                    -not -path '/home/serge/scratch/.stfolder*' \
                    -type d -empty \
                    -print0 | xargs -r -0 rmdir --parents --verbose --ignore-fail-on-non-empty
            fi
        done

        # ~/tmp holds per-invocation Go work dirs (GOTMPDIR); their files are removed
        # above, leaving depth-1 empties the -mindepth 2 loop above cannot see.
        # ~/tmp, depth 1 only: empty directories idle > 48 h.
        logtitle looking for empty go-build dirs directly under ~/tmp
        scan \
            $HOME/tmp \
            -mindepth 1 -maxdepth 1 \
            -type d -empty -mmin ${cleantime} \
            -print0 | xargs -r -0 rmdir --verbose --ignore-fail-on-non-empty
        mkdir -pv $HOME/tmp

        logtitle misc stuff

        # ~/scratch/.stfolder: recreate if missing -- syncthing needs this marker dir to sync
        # ~/scratch at all; belt-and-braces rm first in case it exists as a stray file.
        if ! test -d /home/serge/scratch/.stfolder; then
            logline fix syncthing folder
            rm -rfv /home/serge/scratch/.stfolder
            mkdir -pv /home/serge/scratch/.stfolder
        fi

        # ~/core.* : unconditional rm, any age -- Edge/Chromium crash dumps.
        rm -fv $HOME/core.*

        # ~/logs, recursive: files older than 8 days (11520 min). Redundant with the
        # ${tempfolders} sweep above (~/logs is a member, swept there at 48 h) -- see the note
        # above the retention table. Kept as-is; not changed by this pass.
        logtitle cleanup my logs
        scan $HOME/logs \
            -mindepth 1 \
            -mmin +11520 \
            -type f \
            -print0 | xargs -r -0 rm -fv

        # cleanupo claude files
        logtitle cleanup ~/.claude files
        ## Archive todos older than 30 days - Run daily at 2:30 AM
        # ~/.claude/todos: *.json files older than 30 days.
        # Guarded with -d: the harness has since moved todos elsewhere and this
        # directory no longer exists (2026-09-05) -- an unguarded find on a missing
        # path aborts the whole run under errexit.
        if [ -d "$HOME/.claude/todos" ]; then
            scan $HOME/.claude/todos/ \
                -type f -name "*.json" \
                -mtime +30 \
                -print0 | xargs -r -0 rm -fv
        fi
        # ~/.claude/shell-snapshots: snapshot-*.sh files older than 7 days.
        if [ -d "$HOME/.claude/shell-snapshots" ]; then
            scan $HOME/.claude/shell-snapshots/ \
                -type f -name "snapshot-*.sh" \
                -mtime +7 \
                -print0 | xargs -r -0 rm -fv
        fi
        # Claude Code state with no built-in retention (setup audit 2026-09-06, M1):
        # review-loop transcripts, per-session file-history, g*-loop job dirs, witnessed
        # dry-run markers (30-min TTL, never pruned), debug dumps, settings backups and
        # superseded native-install binaries. Only ~/.claude/projects is pruned by the binary.
        # ~/.claude/reviews: *.md.log review-loop transcripts older than 30 days.
        if [ -d "$HOME/.claude/reviews" ]; then
            scan $HOME/.claude/reviews/ \
                -type f -name "*.md.log" \
                -mtime +30 \
                -print0 | xargs -r -0 rm -fv
        fi
        # claude-sway-urgent.log: the Notification/Stop hook's JSONL audit log, ~700 B per record
        # and ~1000 records a day (measured 2026-10-01: 30402 lines, 21 MB, never trimmed). Over
        # 30000 lines keep the newest 20000. The lock is the one the appender takes (flock on
        # <log>.lock, see ~/binc/claude-sway-urgent), so no record is torn or lost to the mv;
        # umask keeps the replacement owner-only like the original (it can carry command text).
        urgent_log="${XDG_STATE_HOME:-$HOME/.local/state}/claude-sway-urgent.log"
        if [ -f "$urgent_log" ] && [ "$(wc -l <"$urgent_log")" -gt 30000 ]; then
            logtitle trim claude-sway-urgent.log
            flock -w 5 "$urgent_log.lock" -c \
                "umask 077 && tail -n 20000 '$urgent_log' >'$urgent_log.tmp' && mv '$urgent_log.tmp' '$urgent_log'"
        fi
        # ~/.claude/file-history, depth 1: per-session dirs older than 30 days, removed recursively.
        if [ -d "$HOME/.claude/file-history" ]; then
            scan $HOME/.claude/file-history/ \
                -mindepth 1 -maxdepth 1 -type d \
                -mtime +30 \
                -print0 | xargs -r -0 rm -rfv
        fi
        # ~/.claude/jobs, depth 1: g*-loop job dirs older than 30 days, removed recursively.
        if [ -d "$HOME/.claude/jobs" ]; then
            scan $HOME/.claude/jobs/ \
                -mindepth 1 -maxdepth 1 -type d \
                -mtime +30 \
                -print0 | xargs -r -0 rm -rfv
        fi
        # ~/.claude/gates-state: dryrun-* witness markers older than 2 h (their TTL is 30 min,
        # so this just clears out already-expired markers).
        if [ -d "$HOME/.claude/gates-state" ]; then
            scan $HOME/.claude/gates-state/ \
                -maxdepth 1 -type f -name "dryrun-*" \
                -mmin +120 \
                -print0 | xargs -r -0 rm -fv
        fi
        # ~/.claude/debug, depth 1: debug dumps older than 30 days, removed recursively.
        if [ -d "$HOME/.claude/debug" ]; then
            scan $HOME/.claude/debug/ \
                -mindepth 1 -maxdepth 1 \
                -mtime +30 \
                -print0 | xargs -r -0 rm -rfv
        fi
        # ~/.claude, top level: settings*.json.bak* backup files older than 90 days.
        scan $HOME/.claude/ \
            -maxdepth 1 -type f -name "settings*.json.bak*" \
            -mtime +90 \
            -print0 | xargs -r -0 rm -fv
        # ~/.local/share/claude/versions, depth 1: superseded native-install binaries older than
        # 30 days. Keep the ~/.local/bin/claude target and anything < 30 d.
        # A running session keeps its deleted binary's inode, so this never breaks a live one.
        if [ -d "$HOME/.local/share/claude/versions" ]; then
            local current
            current=$(readlink -f "$HOME/.local/bin/claude")
            scan $HOME/.local/share/claude/versions/ \
                -mindepth 1 -maxdepth 1 -type f \
                -mtime +30 ! -path "$current" \
                -print0 | xargs -r -0 rm -fv
        fi

        # Archive rotated nah decision logs. nah keeps one size-based backup (nah.log.1, replaced on
        # every rotation), which with log.verbosity=all is a few days -- the stall report and any
        # re-measurement need >= 4 weeks (~/etc/docs/nah.md). Keyed on the backup's mtime, so this
        # hourly check copies each rotation exactly once whatever the rotation rate.
        # ~/.config/nah/nah.log.1 -> copied into ~/.local/state/nah-log/ (kept regardless of age,
        # one copy per rotation); archived copies there older than 60 days are then pruned.
        logtitle archive rotated nah logs
        local nah_bak="$HOME/.config/nah/nah.log.1"
        local nah_archive="$HOME/.local/state/nah-log"
        mkdir -p "$nah_archive"
        if [ -s "$nah_bak" ]; then
            local nah_dest
            nah_dest="$nah_archive/nah.log.$(date -r "$nah_bak" +%Y%m%dT%H%M%S).jsonl"
            if [ ! -e "$nah_dest" ]; then
                cp -v "$nah_bak" "$nah_dest"
            fi
        fi
        scan "$nah_archive" \
            -maxdepth 1 -type f -name "nah.log.*.jsonl" \
            -mtime +60 \
            -print0 | xargs -r -0 rm -fv

        # Retire abandoned g*-loop state files so they stop rendering as live/STALLED in the HUD.
        # The loops are instructed to write phase=done on exit, but a killed or abandoned session
        # never runs its exit path -- see the header of the script for the F18 history.
        # ~/.claude/reviews/*/state: any state file more than 1 h past its own recorded deadline
        # and not owned by a live pid gets its phase rewritten to `done` (not deleted) --
        # implemented in ~/binc/claude-reviews-state-sweep, called here with no flags (live mode).
        logtitle sweep abandoned ~/.claude/reviews loop states
        $HOME/binc/claude-reviews-state-sweep

    ###############################################################################
    elif [ "${command}" = "update-tools" ]; then

        # Trigger: systemd user timer update-tools.timer, 01/05/09/13/17/21:15.
        # Delegates to ~/bin/update-tools, which runs 12 independent components (mise, mise_tasks,
        # uv_tools, krew, helm, flatpak, misc, downloads, github, ai, bash_completions,
        # shell_init) -- see update-tools:724-735 for the full list and per-component detail.
        $HOME/bin/update-tools

    ###############################################################################
    elif [ "${command}" = "etc-drift" ]; then

        # Trigger: none -- manual only, not currently scheduled anywhere
        # (~/etc/docs/etc-config-mirror.md §Cron).
        # Report drift between the curated /etc mirror (~/etc/r) and live /etc via the
        # `etc:status` mise task (~/etc/mise-tasks/etc/status; see ~/etc/docs/etc-config-mirror.md).
        # It uses `sudo -n`, so root-only files show NEEDS-SUDO in cron; exit 2 means a readable,
        # non-ignored managed file has drifted. Absolute mise path: cron PATH may lack ~/.local/bin.
        "$HOME/.local/bin/mise" --cd "$HOME/etc" run etc:status

    ###############################################################################
    elif [ "${command}" = "firefoxpwa-relink" ]; then

        # Trigger: systemd user timer firefoxpwa-relink.timer, 02/06/10/14/18/22:35.
        # Delegates to ~/bin/firefoxpwa-relink: re-links the firefoxpwa runtime to the local
        # manual-tarball Firefox after that Firefox auto-updates itself in place. BuildID-guarded
        # (marker file), so this is a no-op on every run except right after a Firefox update.
        $HOME/bin/firefoxpwa-relink

    ###############################################################################
    elif [ "${command}" = "nah-stall-report" ]; then

        # Trigger: user crontab, Mondays 07:00.
        # Weekly automation-stall report: real permission prompts joined to the nah
        # decision that preceded them, ask/allow/block ratios, blocks with inputs.
        # Writes ~/.local/state/nah-stall/<ISO week>.md; the tuning loop reads it
        # (~/etc/docs/nah.md §Stall report).
        "$HOME/binc/nah-stall-report"

    ###############################################################################
    elif [ "${command}" = "backup" ]; then

        # Trigger: user crontab, every 2 h at :30. Deliberate no-op -- kept as a placeholder
        # slot in the schedule; nothing runs here today.
        : # no-op

    ###############################################################################
    elif [ "${command}" = "picwide" ]; then

        # Trigger: user crontab, daily 12:30. Four tiers, each filtering the same source tree
        # (~/Documents/Pictures/Wallpapers, via ~/bin/picwide's PICWIDE_ROOT default) by min
        # width/aspect-ratio into its own symlink dir under ~/Wallpapers (defaults: picwide:13-15).

        # Job 1 — strict tier: true ultrawide images for the 7680x2160 (32:9) display.
        # min_width=2560 (default): 2.5K+ ensures clean scaling to 7680px wide (3x upscale max).
        # min_ratio=2.0 (default): 21:9 and wider only — avoids images that stretch badly on a 32:9 screen.
        # Output: ~/Wallpapers/ultrawide
        $HOME/bin/picwide --verbose --update

        # Job 2 — loose tier: same ratio floor but lower resolution floor.
        # min_width=1920: adds HD-wide images (1920×960 etc.) — 4x upscale on this screen, soft but
        #   acceptable for a background at normal viewing distance from a 57" display.
        # min_ratio=2.0 (default): kept identical to job 1 — dropping it further would add 16:9 images
        #   that stretch too aggressively on a 32:9 display with fill mode.
        # Output: ~/Wallpapers/ultrawide2
        PICWIDE_OUTPUT=$HOME/Wallpapers/ultrawide2 PICWIDE_MIN_WIDTH="1920" $HOME/bin/picwide --verbose --update

        # Job 3 — narrower source pool, stricter ratio: min_width=1920, min_ratio=3 (30:9+).
        # Output: ~/Wallpapers/ultrawide3
        PICWIDE_OUTPUT=$HOME/Wallpapers/ultrawide3 PICWIDE_MIN_WIDTH="1920" PICWIDE_MIN_RATIO="3" $HOME/bin/picwide --verbose --update
        # Job 4 — highest-resolution, strictest ratio: min_width=3840 (4K+), min_ratio=3.5.
        # Output: ~/Wallpapers/ultrawide35
        PICWIDE_OUTPUT=$HOME/Wallpapers/ultrawide35 PICWIDE_MIN_WIDTH="3840" PICWIDE_MIN_RATIO="3.5" $HOME/bin/picwide --verbose --update

    ###############################################################################
    elif [ "${command}" = "default" ]; then
        # No action given (or an unrecognized one, see the `else` below). Self-lists every
        # supported action by grepping this file's own `elif ... "${command}" = "<name>"` lines --
        # so this list always matches the branches above without needing separate upkeep.
        echo "supported options:"
        grep 'if .* "${command}" = ' ~/bin/cronjobs.sh | grep -v grep | cut -d\" -f4 | sed s/'^/  - /'

    ###############################################################################
    else
        echo no actions for ${command}
        return 7
    fi

    ###############################################################################
    # Snapshot the live crontab into the vcsh-tracked mirror (repo `sdot`) on every run, on
    # goldorak only -- this is what keeps the action/trigger/schedule table above reviewable
    # from source control instead of only from `crontab -l` on the live host.
    if [ "$(hostname)" = "goldorak" ]; then
        crontab -l >$HOME/etc/config/crontab
    fi
}

#######################################################################################################################

# Always log everything to file. Under cron, only put output on stdout -- which cron
# mails -- when the run actually failed; a healthy hourly cleanup used to mail its full
# "removed '...'" listing every time, which is how a genuine failure sat unnoticed for
# weeks (2026-09-05).
#
# This MUST be an EXIT trap, not `... || status=$?` and not `set +o errexit` around the
# pipeline. Bash suspends errexit for any command whose status is tested by `||`, and that
# suspension reaches all the way down into called functions and subshells -- an inner
# `set -e` does not restore it (verified 2026-09-05). Either of those forms would leave
# `execute` running past its own failures, silently masking them. Leaving the pipeline
# untested keeps errexit live inside `execute`, and `pipefail` (from common.bash) carries
# its status out through `ts` and `log` to the trap.
function on_exit() {
    local status=$?
    if [ "${INTERACTIVE}" = "no" ] && [ "${status}" -ne 0 ]; then
        echo "cronjobs.sh ${command} failed (exit ${status}) -- log: ${LOGFILE}"
        cat "${LOGFILE}" 2>/dev/null || true
    fi
    # Explicit: without this the shell would exit with the status of the last command run
    # inside this trap (the echo/cat above), reporting success for a failed run.
    exit "${status}"
}
trap on_exit EXIT

execute ${command} |& ts | log

#######################################################################################################################
