#!/usr/bin/env bash
set -x

# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t
# vi: set shiftwidth=4 tabstop=4 noexpandtab:
# :indentSize=4:tabSize=4:noTabs=false:

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -o nounset
set -o errexit
set -o pipefail

# shellcheck disable=SC1090
source "$HOME/bin/common.bash"

###############################################################################
if [ -z "${TALOSCONFIG:-}" ]
then
	echo "no TALOSCONFIG set" >&2
	exit 1
elif [ -f "${TALOSCONFIG}" ]
then
	TALOSCONFIG_EXISTED=1
	CONFIG="$(talosctl --talosconfig "${TALOSCONFIG}" config info -o json)"
	CONTEXT="$(echo ${CONFIG} | jq -rc .context)"
	NODES="$(echo ${CONFIG} | jq -rc .nodes)"
	echo "Talos ${CONTEXT} ${NODES}"
fi
