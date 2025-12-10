#!/usr/bin/env bash

# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t
# vi: set shiftwidth=4 tabstop=4 expandtab:
# :indentSize=4:tabSize=4:noTabs=false:

# shellcheck source=/dev/null
source  ~/.bashrc.d/keychain.bash

set -o nounset
set -o errexit
set -o pipefail

# shellcheck disable=SC1090
source "$HOME/bin/common.bash"

###############################################################################
~/Applications/idea-IU/bin/idea.sh &

# https://www.adangel.org/2024/06/21/nofile-limit-investigations/
for pid in $( pgrep -f idea-IU )
do
	prlimit --nofile=1024:1073741816 -p $pid
done
wait
