#!/usr/bin/env bash

# c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t
# vi: set shiftwidth=4 tabstop=4 expandtab:
# :indentSize=4:tabSize=4:noTabs=false:

set -o nounset
set -o errexit
set -o pipefail

dumpdir="./allyaml"
clusterscope="_cluster_scope"

NAMESPACES="$(kubectl get namespaces --output=custom-columns=NAME:.metadata.name | grep -v NAME)" || true
OBJECTS_NS="$(kubectl api-resources --verbs=list --namespaced="true" --output=name)" || true
OBJECTS_GL="$(kubectl api-resources --verbs=list --namespaced="false" --output=name)" || true

for ns in ${NAMESPACES}
do
	for obj in ${OBJECTS_NS}
	do
		mkdir -p "./${dumpdir}/${ns}/${obj}"
		objects="$(kubectl --namespace "${ns}" get "${obj}" --output=custom-columns=NAME:.metadata.name 2>/dev/null | grep -v NAME)" || true
		for obji in ${objects}
		do
			kubectl --namespace "${ns}" get "${obj}" "${obji}" -o yaml > "./${dumpdir}/${ns}/${obj}/${obji}.yaml" 2>/dev/null || true
		done
	done
done

for obj in ${OBJECTS_GL}
do
	objects="$(kubectl get "${obj}" --output=custom-columns=NAME:.metadata.name 2>/dev/null | grep -v NAME)" || true
	for obji in ${objects}
	do
		mkdir -p "./${dumpdir}/${clusterscope}/${obj}"
		kubectl get "${obj}" "${obji}" -o yaml > "./${dumpdir}/${clusterscope}/${obj}/${obji}.yaml" 2>/dev/null || true
	done
done
