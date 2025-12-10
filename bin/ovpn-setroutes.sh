#!/usr/bin/env bash
set -o nounset
set -o errexit
set -o pipefail

# openvpn route-up/down script
# for use with route-noexec to avoid being set a default gateway
## route-noexec
## route-up ovpn-setroutes.sh
## route-pre-down ovpn-setroutes.sh

for i in `seq 1 9`
do
    for vartype in route_gateway route_netmask route_network
    do
        varname=${vartype}_${i}
        [ ! -z "${!varname}" ] && eval ${vartype}[$i]=${!varname}
    done
    if [ ! -z "${route_network[$i]}" ]
    then
        case ${script_type} in
            "route-up")
                route add -net ${route_network[$i]} netmask ${route_netmask[$i]} gw ${route_gateway[$i]}
                ;;
            "route-pre-down")
                route del -net ${route_network[$i]} netmask ${route_netmask[$i]} gw ${route_gateway[$i]}
                ;;
            *)
                set > log
                exit 1
                ;;
        esac
    fi
done
exit 0

