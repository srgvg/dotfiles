#!/bin/bash
# Detect all subjects with nodes/proxy permissions
# https://grahamhelton.com/blog/nodes-proxy-rce

# Colors
NOCOLOR=$(tput sgr0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
DIM=$(tput setaf 8)

# Formatting
DIV="$DIM---------------------------------------------------------------------$NOCOLOR"
TICK="[$GREEN+$NOCOLOR]"
TICK_WARN="[$YELLOW!$NOCOLOR]"
TICK_INFO="[$CYAN-$NOCOLOR]"

echo "$TICK Scanning for nodes/proxy permissions..."
echo
echo "NOTE: This script only finds explicit nodes/proxy grants by parsing ClusterRole YAML."
echo "It does NOT detect inherited permissions from cluster-admin or wildcard roles."
echo "For comprehensive coverage, use something like https://github.com/aquasecurity/kubectl-who-can $NOCOLOR"
echo

# Get all ClusterRoles with nodes/proxy
roles=$(kubectl get clusterroles -o json | jq -r '
    .items[] |
    .metadata.name as $name |
    .rules[]? |
    select(.resources[]? | test("nodes/proxy|nodes/\\*")) |
    $name' | sort -u)

# Check ClusterRoleBindings
echo "$DIV"
echo "$TICK Checking ClusterRoleBindings"
for role in $roles; do
    kubectl get clusterrolebindings -o json | jq -c --arg r "$role" '
        .items[] |
        select(.roleRef.name == $r) |
        .subjects[]? |
        {kind: .kind, namespace: (.namespace // "default"), name: .name, role: $r}'
done | sort -u | while read -r line; do
    kind=$(echo "$line" | jq -r '.kind')
    ns=$(echo "$line" | jq -r '.namespace')
    name=$(echo "$line" | jq -r '.name')
    role=$(echo "$line" | jq -r '.role')

    if [[ "$kind" == "ServiceAccount" ]]; then
        echo "$TICK_WARN ${RED}Vulnerable Service Account:$NOCOLOR $ns/$name -> $role"
        echo "  ${DIM}Verify: kubectl auth can-i get nodes --subresource=proxy --as=system:serviceaccount:$ns:$name$NOCOLOR"
        echo
    else
        echo "$TICK_INFO [$kind] $ns/$name -> $role"
    fi
done

echo
echo "$DIV"
echo "$TICK Checking RoleBindings"
for role in $roles; do
    kubectl get rolebindings -A -o json | jq -c --arg r "$role" '
        .items[] |
        select(.roleRef.name == $r) |
        .metadata.namespace as $ns |
        .subjects[]? |
        {kind: .kind, namespace: (.namespace // "default"), name: .name, role: $r, binding_ns: $ns}'
done | sort -u | while read -r line; do
    kind=$(echo "$line" | jq -r '.kind')
    ns=$(echo "$line" | jq -r '.namespace')
    name=$(echo "$line" | jq -r '.name')
    role=$(echo "$line" | jq -r '.role')
    binding_ns=$(echo "$line" | jq -r '.binding_ns')

    if [[ "$kind" == "ServiceAccount" ]]; then
        echo "$TICK_WARN ${RED}Vulnerable Service Account:$NOCOLOR $ns/$name -> $role ${DIM}(binding ns: $binding_ns)$NOCOLOR"
        echo "  ${DIM}Verify: kubectl auth can-i get nodes --subresource=proxy --as=system:serviceaccount:$ns:$name$NOCOLOR"
        echo
    else
        echo "$TICK_INFO [$kind] $ns/$name -> $role ${DIM}(binding ns: $binding_ns)$NOCOLOR"
    fi
done

echo "$DIV"
