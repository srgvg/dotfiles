#!/bin/bash

self=`readlink -f $0`
basedir=`dirname $self`

export BORG_PASSPHRASE=$(grep ^encryption_passphrase $basedir/borgmatic.cfg | awk '{print $2}')
REPOSITORY=rsync.net:minos

command=${1:-list}
shift

echo borg $command --remote-path /usr/local/bin/borg1/borg1 ${*:-$REPOSITORY}
borg $command --remote-path /usr/local/bin/borg1/borg1 ${*:-$REPOSITORY}

