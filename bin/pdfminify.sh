#!/usr/bin/env bash

# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t
# vi: set shiftwidth=4 tabstop=4 noexpandtab:
# :indentSize=4:tabSize=4:noTabs=false:

set -o nounset
set -o errexit
set -o pipefail

# shellcheck disable=SC1090
source "$HOME/bin/common.bash"

###############################################################################


file=${1:-}
pdfout="${2:-${file%.*}-restricted.pdf}"
pdfout="${pdfout%.*}.pdf"

echo gs -sDEVICE=pdfwrite \
     -dCompatibilityLevel=1.4 \
     -dDownsampleColorImages=true \
     -dColorImageResolution=150 \
     -dNOPAUSE \
     -dBATCH \
     -sOutputFile="${pdfout}" "${file}"
