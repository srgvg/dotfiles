#!/usr/bin/env bash

# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t
# vi: set shiftwidth=4 tabstop=4 expandtab:
# :indentSize=4:tabSize=4:noTabs=false:

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -o nounset
set -o errexit
set -o pipefail

###############################################################################

tmpf="$(mktemp)"

nice -n 20 ionice -c 3 find $BACKGROUND_PICTURES -type f \( -iname '*.png'  -o -iname '*.jpg'  -o -iname '*.jpeg' \) -exec picorient {} \; > ${tmpf}

mv ${tmpf} $BACKGROUND_PICTURES/index.txt
