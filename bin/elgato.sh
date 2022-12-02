#!/bin/bash

# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t
# vi: set shiftwidth=4 tabstop=4 noexpandtab:
# :indentSize=4:tabSize=4:noTabs=false:

set -o nounset
set -o errexit
set -o pipefail

# shellcheck disable=SC1090
source "$HOME/bin/common.bash"

###############################################################################

elgato $@
notify_desktop_always low "Elgato Desktop Light" "$((elgato lights | grep 'power: off' || elgato lights | grep -e brightness -e color) | xargs)" night-light-symbolic
