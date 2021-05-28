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

if [ $# -eq 0 ]; then
    file=$(pwgen 10)
    cat - >&2 <<-EOF
	No arguments specified. Usage:

	  transfer <file|directory> [maxdays] [maxdownloads]
	  <command to stdout> | transfer <file_name>

	  Now Using random filename ${file}


	EOF
else
  file="$1"
fi
file_name=$(basename "$file")

maxdays=${2:-2}
maxdown=${3:-9999}

maxdaysh="Max-days: $maxdays"
maxdownh="Max-Downloads: ${maxdown}"

CURLCOMMAND="curl --dump-header /dev/stdout --progress-bar --upload-file - "
CURLURL="https://transfer.home.vanginderachter.be/"
GREPCURL="grep -e x-url-delete -e $CURLURL"

function upload() {
if test -t 0; then  # stdin is terminal, not piped
    if [ ! -e "$file" ]; then
        echo "$file: No such file or directory">&2
        exit 1
    fi
    if [ -d "$file" ]; then
        file_name="$file_name.zip"
        cd "$file"
        zip -r -q - . | ${CURLCOMMAND} -H "${maxdaysh} ${maxdays}" -H "${maxdownh}" ${CURLURL}${file_name} | ${GREPCURL}
    else
		cat "$file"   | ${CURLCOMMAND} -H "${maxdaysh} ${maxdays}" -H "${maxdownh}" ${CURLURL}${file_name} | ${GREPCURL}
    fi
else
        cat -         | ${CURLCOMMAND} -H "${maxdaysh} ${maxdays}" -H "${maxdownh}" ${CURLURL}${file_name} | ${GREPCURL}
fi
}

returninfo=$(upload)
echo
baseurl="https://transfer.office.ginsys.eu/"
urlxdelete=$(echo -ne "${returninfo}" | grep x-url-delete | cut -d: -f2- | cut -d/ -f6)
urllocation=$(echo -ne "${returninfo}" | grep -v x-url-delete | cut -d/ -f4-5)

parse() {
	echo -e "DELETE: \tcurl -X DELETE ${baseurl}${urllocation}/${urlxdelete}"
	echo -e "ONPAGE: \t${baseurl}${urllocation}"
	echo -e "INLINE: \t${baseurl}inline/${urllocation}"
	echo -e "DIRECT: \t${baseurl}get/${urllocation}"
}
parse
echo -e "${baseurl}inline/${urllocation}" | xclip -in -selection c



