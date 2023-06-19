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

app_name="${1:-}"
shift ||:
app_args="${*:-}"

if [ -z "${app_name}" ]
then
	app_name="$(flatpak list --columns=name,application  | fzf | awk '{print $NF}')"
fi

# NF is number of fields, so it always prints the last column (first column can have spaces...)
app_id="$(flatpak list --columns=name,application | grep -i "${app_name}" | head -n1 | awk '{print $NF}')"
if [ -z "${app_id}" ]
then
	echo Application ${app_name} not found.
	exit 1
fi

if flatpak ps | grep -q "${app_id}"
then
	echo flatpak "${app_id}" is already running
	sleep 5
else
	echo flatpak run --verbose "${app_id}" ${app_args}
	echo =========================================================================
	echo
	flatpak run --verbose "${app_id}" ${app_args}

	## because they sometimes go to background
	if flatpak ps | grep -q "${app_id}"
	then
		pid="$(flatpak ps --columns=application,child-pid | grep com.spotify.Client | awk '{print $2}')"
		while flatpak ps | grep -q "${app_id}"
		do
			sleep 5
		done
		if test -d /proc/${pid}
		then
			while test -d /proc/${pid}
			do
				sleep 5
			done
		fi
	fi
fi
