#!/bin/bash

dumpdir="./allyaml"
clusterscope=_cluster_scope

NAMESPACES="$(kubectl get namespaces --output=custom-columns=NAME:.metadata.name | grep -v NAME)"
OBJECTS_NS="$(kubectl api-resources --verbs=list --namespaced="true" --output=name)"
OBJECTS_GL="$(kubectl api-resources --verbs=list --namespaced="false" --output=name)"

for ns in ${NAMESPACES}
do
	for obj in ${OBJECTS_NS}
	do
		mkdir -p ./$dumpdir/$ns/$obj
		objects="$(kubectl --namespace $ns get $obj --output=custom-columns=NAME:.metadata.name | grep -v NAME)"
		for obji in $objects
		do
			kubectl --namespace $ns get $obj $obji -o yaml > ./$dumpdir/$ns/$obj/$obji.yaml
		done
	done
done
for obj in ${OBJECTS_GL}
do
	objects="$(kubectl get $obj --output=custom-columns=NAME:.metadata.name | grep -v NAME)"
	for obji in $objects
	do
		mkdir -p ./$dumpdir/$clusterscope/$obj
		kubectl get $obj $obji -o yaml > ./$dumpdir/$clusterscope/$obj/$obji.yaml
	done
done
