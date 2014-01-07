#!/bin/bash
# screen_ssh.sh by Chris Jones <cmsj@tenshu.net>
# Released under the GPL v2 licence.
# Set the title of the current screen to the hostname being ssh'd to
#
# usage: screen_ssh.sh $PPID hostname
#
# This is intended to be called by ssh(1) as a LocalCommand.
# For example, put this in ~/.ssh/config:
#
# Host *
#   LocalCommand /path/to/screen_ssh.sh $PPID %n

# If it's not working and you want to know why, set DEBUG to 1 and check the
# logfile.
DEBUG=0
DEBUGLOG="$HOME/.ssh/screen_ssh.log"

set -e
set -u

dbg ()
{
  if [ "$DEBUG" -gt 0 ]; then
    echo "$(date) :: $*" >>$DEBUGLOG
  fi
}

dbg "$0 $*"

# We only care if we are in a terminal
tty -s

# We also only care if we are in screen, which we infer by $TERM starting
# with "screen"
if [ "${TERM:0:6}" != "screen" ]; then
  dbg "Not a screen session, ${TERM:0:5} != 'screen'"
  exit
fi

# We must be given two arguments - our parent process and a hostname
# (which may be "%n" if we are being called by an older SSH)
if [ $# != "2" ]; then
  dbg "Not given enough arguments (must have PPID and hostname)"
  exit
fi

# We don't want to do anything if BatchMode is on, since it means
# we're not an interactive shell
set +e
grep -a -i "Batchmode yes" /proc/$1/cmdline >/dev/null 2>&1
RETVAL=$?
if [ "$RETVAL" -eq "0" ]; then
  dbg "SSH is being used in Batch mode, exiting because this is probably an auto-complete or similar"
  exit
fi
set -e

# Infer which version of SSH called us, and use an appropriate method
# to find the hostname
if [ "$2" = "%n" ]; then
  HOST=$(xargs -0 < /proc/$1/cmdline)
  dbg "Using OpenSSH 4.x hostname guess: $HOST"
else
  HOST="$2"
  dbg "Using OpenSSH 5.x hostname specification: $HOST"
fi

echo $HOST | sed -e 's/\.[^.]*\.[^.]*\(\.uk\)\{0,1\}$//' | awk '{ printf ("\033k%s\033\\", $NF) }'

dbg "Done."
