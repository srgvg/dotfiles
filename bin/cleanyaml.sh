#!/usr/bin/env bash
set -o nounset
set -o errexit
set -o pipefail

function cleanyaml () {
	(
		yq -i eval '
			del(.metadata.labels.workflowFriendlyName) |
			del(.metadata.labels.workflow) |
			del(.metadata.labels.modifiedAt) |
			del(.metadata.labels.status) |
			del(.metadata.labels.version) |
			del(.metadata.labels.owner) |
			del(.metadata.["app.kubernetes.io/instance"]) |
			del(.metadata.["app.kubernetes.io/managed-by"]) |
			del(.metadata.["helm.sh/chart"]) |
			del(.metadata.annotations.["meta.helm.sh/release-name"]) |
			del(.metadata.annotations.["meta.helm.sh/release-namespace"]) |
			del(.metadata.annotations.["actions.github.com/k8s-deploy"]) |
			del(.metadata.annotations.["actions.github.c"]) |
			del(.metadata.annotations.["deployment.kubernetes.io/revision"]) |
			del(.spec.clusterIP) |
			del(.spec.ipFamilyPolicy) |
			del(.spec.ipFamilies) |
			del(.spec.clusterIPs)
			' -o yaml $1
		yamlfmt $1
	) &
}

if [ -z "${1:-}" ]
then
	for manifest in $(find -type f -name '*.yaml')
	do
		echo cleanyaml $manifest
		cleanyaml $manifest
	done
else
	manifest="${1}"
	echo cleanyaml $manifest
	cleanyaml $manifest
fi
wait
