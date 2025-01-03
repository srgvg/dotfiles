#!/usr/bin/env bash

# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t
# vi: set shiftwidth=4 tabstop=4 noexpandtab:
# :indentSize=4:tabSize=4:noTabs=false:

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -o nounset
set -o errexit
set -o pipefail

###############################################################################

tmpf="$(mktemp)"

nice -n 20 ionice -c 3 find $HOME/Documents/Pictures/Backgrounds/ -type f \( -iname '*.png'  -o -iname '*.jpg'  -o -iname '*.jpeg' \) -exec picorient {} \; > ${tmpf}

mv ${tmpf} $HOME/Documents/Pictures/Backgrounds/index.txt
