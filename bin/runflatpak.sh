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
shift

if [ -z "${app_name}" ] 
then
	echo Application ${app_name} not given.
	exit 1
fi

app_id="$(flatpak list --columns=name,application | grep -i ^"${app_name}" | head -n1 | awk '{print $NF}')"
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
	echo flatpak run --verbose "${app_id}" $*
	echo =========================================================================
	echo 
	flatpak run --verbose "${app_id}" $*
	
	# because they sometimes go to background
	while flatpak ps | grep -q "${app_id}"
	do
		sleep 5
	done
fi