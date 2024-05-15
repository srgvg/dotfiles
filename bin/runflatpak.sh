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

app_name="$(basename $0)"
# select pak to run
if [[ "${app_name}" =~ flatpak ]]
# script called by its own name, not via app-named symlink
then
	# app should be first argument
	if [ -z "${1:-}" ]
	then
		# interactively select app
		app_name="$(flatpak list --columns=name,application  | fzf | awk '{print $NF}')"
	else
		echo trying to launch app $app_name
		shift
	fi
fi

app_args="${*:-}"
if [ -n "${app_args}" ]
then
	echo application arguments: $app_args
fi

# NF is number of fields, so it always prints the last column (first column can have spaces...)
app_id="$(flatpak list --columns=name,application | grep -i "${app_name}" | head -n1 | awk '{print $NF}')"
if [ -z "${app_id}" ]
then
	echo Application ${app_name} not found.
	exit 1
elif flatpak ps | grep -q "${app_id}"
then
	echo flatpak "${app_id}" is already running
	echo =========================================================================
	echo flatpak run --verbose "${app_id}" ${app_args}
	echo =========================================================================
	echo
	flatpak run --verbose "${app_id}" ${app_args}
else
	echo =========================================================================
	echo flatpak run --verbose "${app_id}" ${app_args}
	echo =========================================================================
	echo
	i3-launch-jobs flatpak run --verbose "${app_id}" ${app_args}

	## because they sometimes go to background
	#while flatpak ps | grep -q "${app_id}"
	#do
	#	sleep 5
	#done
fi
