#!/usr/bin/env bash
set -o nounset
set -o errexit
set -o pipefail

self=`readlink -f $0`
basedir=`dirname $self`

export BORG_PASSPHRASE=$(grep ^encryption_passphrase $basedir/borgmatic.cfg | awk '{print $2}')
REPOSITORY=rsync.net:minos

command=${1:-list}
shift

set -x
borg $command ---info --debug  -remote-path /usr/local/bin/borg1/borg1 ${*:-$REPOSITORY}
set +x

