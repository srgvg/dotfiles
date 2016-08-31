#!/usr/bin/env bash
# screen_ssh.sh by Chris Jones <cmsj@tenshu.net>
# Released under the GNU GPL v2 licence.
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
# if [ "${TERM:0:6}" != "screen" ]; then
#   dbg "Not a screen session, ${TERM:0:5} != 'screen'"
#   exit
# fi

# We must be given two arguments - our parent process and a hostname
# (which may be "%n" if we are being called by an older SSH)
if [ $# != "2" ]; then
  dbg "Not given enough arguments (must have PPID and hostname)"
  exit
fi

# We don't want to do anything if BatchMode is on, since it means
# we're not an interactive shell
# set +e
# grep -a -i "Batchmode yes" /proc/$1/cmdline >/dev/null 2>&1
# RETVAL=$?
# if [ "$RETVAL" -eq "0" ]; then
#   dbg "SSH is being used in Batch mode, exiting because this is probably an auto-complete or similar"
#   exit
# fi
# set -e

# Infer which version of SSH called us, and use an appropriate method
# to find the hostname
# if [ "$2" = "%n" ]; then
#   HOST=$(xargs -0 < /proc/$1/cmdline)
#   dbg "Using OpenSSH 4.x hostname guess: $HOST"
# else
#  HOST="$2"
# fi

HOST="$2"

# detect if hostname from parameter is IP address
if echo "$HOST" | grep -Eq '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'; then

  # .ssh/config substitution needed

  # searching if HOST in .ssh/config
  NEW_HOST=`sed -n "
/^Host ./{
  # for new Host, write value in the buffer
  s/^Host \([^ ]*\).*/\\1/
  h;
}

/^HostName/{
  /$HOST/{
    # match of IP address - found result. Print hold space and exit
    x; p; q;
  }
}" $HOME/.ssh/config`


  # if NEW_HOST not empty replace HOST
  if [ -n NEW_HOST ]; then
    HOST=$NEW_HOST
  fi

fi

WIN_NAME="$HOST"
#echo $WIN_NAME    # debug new screen window name

# maximum screen window name is 20 chars
if [ `printf %s $WIN_NAME | wc -c` -gt 20 ]; then
  WIN_NAME="`echo $WIN_NAME | cut -c 1-19`_"         # cuts the win_name to 19 chars and appends '_'
fi


#echo $STRING | sed -e 's/\.[^.]*\.[^.]*\(\.uk\)\{0,1\}$//' | awk '{ printf ("\033k%s\033\\", $NF) }'
echo $WIN_NAME | awk '{ printf ("\033k%s\033\\", $NF) }'

dbg "Done."
