#!/usr/bin/env bash
set -euo pipefail

# One-page KubeSpan overview using nodes from the active talosctl config (TALOSCONFIG respected).
# Requires: talosctl, jq (works on jq 1.6+)

usage() {
    cat <<'EOF'
Usage: kubespan-top.sh [NODE ...]

Show a one-page KubeSpan overview.

If NODE arguments are provided, only those nodes are queried. Otherwise the
active talosctl config is used: .nodes when present, falling back to .endpoints.

Environment:
  TALOSCONFIG             talosctl config path
  TALOS_TIMEOUT_SECONDS   per-node query timeout, default: 12
EOF
}

NODES=()
while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            while [ "$#" -gt 0 ]; do
                NODES+=("$1")
                shift
            done
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
        *)
            NODES+=("$1")
            ;;
    esac
    shift
done

tmp_peer="$(mktemp)"
tmp_ep="$(mktemp)"
tmp_spec="$(mktemp)"
tmp_host="$(mktemp)"
tmp_mem="$(mktemp)"
tmp_perr="$(mktemp)"
tmp_eerr="$(mktemp)"
tmp_serr="$(mktemp)"
tmp_herr="$(mktemp)"
tmp_merr="$(mktemp)"
tmp_dir="$(mktemp -d)"
trap 'rm -f "$tmp_peer" "$tmp_ep" "$tmp_spec" "$tmp_host" "$tmp_mem" "$tmp_perr" "$tmp_eerr" "$tmp_serr" "$tmp_herr" "$tmp_merr"; rm -rf "$tmp_dir"' EXIT

if [ "${#NODES[@]}" -eq 0 ]; then
    mapfile -t NODES < <(
        talosctl config info -o json |
            jq -r '
              def array_or_empty: if type == "array" then . else [] end;
              (.nodes // [] | array_or_empty) as $nodes
              | (.endpoints // [] | array_or_empty) as $endpoints
              | if ($nodes | length) > 0 then $nodes[] else $endpoints[] end
            ' |
            sort -u
    )
fi

if [ "${#NODES[@]}" -eq 0 ]; then
    echo "No nodes found in talosctl config. Check TALOSCONFIG / talosctl context."
    exit 2
fi

# Normalize Talos JSON output to a single flat array:
# - supports: a single array, multiple JSON documents, and {items:[...]} wrappers
normalize_to_array='
  [ .[]
    | ((.items? // .)
      | if type=="array" then . else [.] end)
  ] | flatten
'

# Fetch one resource from one node. Output is always a JSON array, even on
# failure, so partial data from other nodes can still be reported.
fetch_one() {
    local resource="$1"
    local node="$2"
    local output="$3"
    local errfile="$4"
    local timeout_seconds="${TALOS_TIMEOUT_SECONDS:-12}"

    if timeout "$timeout_seconds" talosctl -n "$node" get "$resource" -o json 2>"$errfile" |
        jq -cs "$normalize_to_array" >"$output"; then
        return 0
    fi

    echo '[]' >"$output"
    if [ ! -s "$errfile" ]; then
        echo "query timed out or returned no data" >"$errfile"
    fi
}

# Fetch each resource type from each node concurrently. This avoids the
# all-or-nothing behavior of a single multi-node talosctl call.
# $1 = resource type, $2 = output file, $3 = stderr capture file
fetch() {
    local resource="$1"
    local output="$2"
    local errout="$3"
    local files=()
    local i=0

    : >"$errout"
    for node in "${NODES[@]}"; do
        i=$((i + 1))
        local node_output="$tmp_dir/${resource}.${i}.json"
        local node_err="$tmp_dir/${resource}.${i}.err"
        files+=("$node_output")
        fetch_one "$resource" "$node" "$node_output" "$node_err" &
    done
    wait

    for i in "${!NODES[@]}"; do
        local node_err="$tmp_dir/${resource}.$((i + 1)).err"
        if [ -s "$node_err" ]; then
            sed "s/^/${resource} ${NODES[$i]}: /" "$node_err" >>"$errout"
        fi
    done

    jq -s 'add' "${files[@]}" >"$output"
}

fetch kubespanpeerstatuses "$tmp_peer" "$tmp_perr" &
fetch kubespanendpoints    "$tmp_ep"   "$tmp_eerr" &
fetch kubespanpeerspecs    "$tmp_spec" "$tmp_serr" &
fetch hostname             "$tmp_host" "$tmp_herr" &
fetch members              "$tmp_mem"  "$tmp_merr" &
wait

# Flag selected nodes that did not return at least one requested resource.
failed_nodes=$(cat "$tmp_perr" "$tmp_eerr" "$tmp_serr" "$tmp_herr" "$tmp_merr" 2>/dev/null |
    awk -F'[: ]+' '/^[a-zA-Z0-9]+ / { print $2 }' |
    sort -u |
    paste -sd, -)
if [ -n "$failed_nodes" ]; then
    echo "WARNING: partial/no data from selected nodes: $failed_nodes" >&2
fi

peer_count=$(jq 'length' "$tmp_peer")
if [ "$peer_count" -eq 0 ]; then
    echo "KubeSpan overview (all selected nodes)"
    echo "------------------------------------------------------------------------------"
    echo "No KubeSpan peer status data collected."
    echo
    echo "Selected nodes: ${NODES[*]}"
    if [ -n "$failed_nodes" ]; then
        echo "Nodes with query errors: $failed_nodes"
    fi
    echo
    echo "This is not a healthy/no-issues result; it means the dashboard had no peer-status facts to evaluate."
    exit 1
fi

now_epoch="$(date +%s)"

jq -rn --argjson NOW "$now_epoch" --slurpfile peers "$tmp_peer" --slurpfile eps "$tmp_ep" --slurpfile specs "$tmp_spec" --slurpfile hosts "$tmp_host" --slurpfile mems "$tmp_mem" '
  # Get the node this peer status was collected from (the reporting node)
  def node:
    .node
    // .metadata.labels["talos.dev/nodename"]
    // .metadata.labels["kubernetes.io/hostname"]
    // .metadata.hostname
    // .metadata.node
    // .metadata.id
    // "unknown-node";

  # Get peer identifier (the remote peer label or ID)
  def peer_id:
    .spec.label
    // .metadata.id
    // .metadata.name
    // .spec.publicKey
    // "unknown-peer";

  def state:
    (.spec.state // "unknown") | tostring | ascii_downcase;

  def endpoint:
    (.spec.endpoint // "") | tostring;

  def rx: ((.spec.receiveBytes // 0) | tonumber);
  def tx: ((.spec.transmitBytes // 0) | tonumber);

  def hs_epoch:
    (.spec.lastHandshakeTime // null) as $t
    | if $t == null then null
      elif ($t|type) == "number" then ($t|floor)
      elif ($t|type) == "string" then
        # Strip fractional seconds for fromdateiso8601 compatibility
        ($t | split(".")[0] + "Z") as $normalized
        | try ($normalized | fromdateiso8601) catch null
      else null end;

  def age_s:
    (hs_epoch) as $h | if $h == null then null else ($NOW - $h) end;

  def fmt_bytes($b):
    if $b == null then "0B"
    elif $b < 1024 then "\($b)B"
    elif $b < 1024*1024 then "\(($b/1024)|floor)KiB"
    elif $b < 1024*1024*1024 then "\(($b/1024/1024*10)|floor/10)MiB"
    else "\(($b/1024/1024/1024*10)|floor/10)GiB" end;

  def fmt_age($s):
    if $s == null then "n/a"
    elif $s < 60 then "\($s)s"
    elif $s < 3600 then "\(($s/60)|floor)m"
    elif $s < 86400 then "\(($s/3600)|floor)h"
    else "\(($s/86400)|floor)d" end;

  ($peers[0] // []) as $p
  | ($eps[0] // []) as $e
  | ($specs[0] // []) as $s
  # Map reporting-node IP -> hostname (from the `hostname` resource); fall back to IP.
  | (($hosts[0] // []) | map({ key: .node, value: .spec.hostname }) | from_entries) as $hostmap
  # Discovery members, as reported by each queried node (each node has its own view).
  | ($mems[0] // []) as $m
  | ($m | map(node) | unique) as $reportingIPs
  | ($reportingIPs | length) as $reporting

  | "KubeSpan overview (selected nodes)"
  , "------------------------------------------------------------------------------"
  , "NODE                    PEERS   UP  DOWN   WORST_HS   RX       TX      EPS"
  , "------------------------------------------------------------------------------"

  , (
      $p
      | sort_by(node)
      | group_by(node)
      | map({
          n: (.[0] | node),
          total: length,
          up: (map(select(state=="up" or state=="connected")) | length),
          down: (map(select(state!="up" and state!="connected")) | length),
          worst_age: (map(age_s) | map(select(. != null)) | if length==0 then null else max end),
          rx_sum: (map(rx) | add),
          tx_sum: (map(tx) | add)
        })
      | sort_by(.n)
      | .[]
      | . as $row
      | ($hostmap[$row.n] // $row.n) as $rowname
      | ($rowname | if length < 22 then . + (" " * (22 - length)) else .[0:22] end)
        + "  "
        + (($row.total|tostring) | (if length<5 then (" "*(5-length)) + . else . end))
        + "  "
        + (($row.up|tostring)    | (if length<3 then (" "*(3-length)) + . else . end))
        + "  "
        + (($row.down|tostring)  | (if length<4 then (" "*(4-length)) + . else . end))
        + "   "
        + ((fmt_age($row.worst_age)) | (if length<8 then (" "*(8-length)) + . else . end))
        + "   "
        + ((fmt_bytes($row.rx_sum))  | (if length<7 then (" "*(7-length)) + . else . end))
        + "  "
        + ((fmt_bytes($row.tx_sum))  | (if length<7 then (" "*(7-length)) + . else . end))
        + "  "
        + (
            ($s
              | map(select((.node // .metadata.labels["talos.dev/nodename"] // .metadata.hostname // .metadata.node // .metadata.id) == $row.n))
              | map((.spec.endpoints // []) | length)
              | if length == 0 then 0 else add end
            ) | tostring
          )
    )

  , ""
  , "Discovery members (\($reporting) reporting node(s); SEEN = how many list it, ! = fragmented)"
  , "------------------------------------------------------------------------------"
  , "MEMBER                  TYPE          OS                  SEEN    TUNNEL   ADDRESSES"
  , (
      if ($m | length) == 0 then "No discovery member data collected (nodes unreachable, or none joined)."
      else
        $m
        | group_by(.metadata.id // .spec.hostname)
        | map({
            host:  (.[0].spec.hostname // .[0].metadata.id // "unknown"),
            mtype: (.[0].spec.machineType // "?"),
            os:    (.[0].spec.operatingSystem // "?"),
            addrs: (.[0].spec.addresses // []),
            seen:  (map(node) | unique | length)
          })
        | sort_by(.host)
        | .[] as $mem
        | ($mem.host) as $h
        | ($p | map(select(.spec.label == $h))) as $mp
        | ($reportingIPs | any(. as $ip | ($mem.addrs | index($ip)))) as $isSelf
        | (if $isSelf then "self"
           elif ($mp | length) == 0 then "-"
           elif ($mp | any(state=="up" or state=="connected")) then "up"
           else "down" end) as $tun
        | ("\($mem.seen)/\($reporting)" + (if $mem.seen < $reporting then "!" else "" end)) as $seenStr
        | ($h        | if length<22 then . + (" " * (22-length)) else .[0:22] end)
          + "  " + ($mem.mtype | if length<12 then . + (" " * (12-length)) else .[0:12] end)
          + "  " + ($mem.os    | if length<18 then . + (" " * (18-length)) else .[0:18] end)
          + "  " + ($seenStr   | if length<6  then . + (" " * (6-length))  else . end)
          + "  " + ($tun       | if length<7  then . + (" " * (7-length))  else . end)
          + "  " + ($mem.addrs | join(","))
      end
    )
  , ""
  , "  TUNNEL: up/down = KubeSpan peer state seen from queried nodes; self = a queried node; - = no peer entry."

  , ""
  , "Endpoint details per peer"
  , "-------------------------"
  , "PEER                   CURRENT ENDPOINT             AVAILABLE ENDPOINTS"
  , (
      # Get unique peers with their endpoint info (deduplicated by peer label)
      $p
      | sort_by(.spec.label)
      | group_by(.spec.label)
      | map(.[0])  # Take first occurrence of each peer
      | sort_by(.spec.label)
      | .[] as $peer
      | ($s | map(select(.spec.label == $peer.spec.label)) | .[0]) as $spec
      | {
          label: $peer.spec.label,
          current: $peer.spec.endpoint,
          lastUsed: $peer.spec.lastUsedEndpoint,
          available: ($spec.spec.endpoints // [])
        }
      | .label as $lbl
      | .current as $cur
      | .lastUsed as $last
      | .available as $avail
      | ($lbl | if length < 22 then . + (" " * (22 - length)) else .[0:22] end) as $lblPad
      | ($cur | if length < 28 then . + (" " * (28 - length)) else .[0:28] end) as $curPad
      # Extract IP from current endpoint for comparison (handle [ipv6]:port and ip:port)
      | ($cur | gsub("^\\[|\\]:[0-9]+$|:[0-9]+$"; "")) as $curIP
      # Mark which endpoints are in use (compare by IP, ignoring port for matching)
      | ($avail | map(
          . as $ep
          | ($ep | gsub("^\\[|\\]:[0-9]+$|:[0-9]+$"; "")) as $epIP
          | if $epIP == $curIP then "*\($ep)"
            else $ep
          end
        ) | join(", ")) as $epList
      | "\($lblPad) \($curPad) \($epList)"
    )
  , ""
  , "  * = currently in use"

  , ""
  , "Issues (down/unknown peers, up to 12) — NODE cannot reach PEER"
  , "--------------------------------------------------------------"
  , (
      $p
      | map({ n: node, peer: peer_id, st: state, ep: endpoint, hs: age_s, rx: rx, tx: tx })
      | map(select(.st!="up" and .st!="connected"))
      | sort_by(.hs // 1e18) | reverse
      | .[0:12]
      | if length==0 then "No down/unknown peers detected (from the selected nodes)."
        else .[]
          | (($hostmap[.n] // .n)
             | if length < 22 then . + (" " * (22 - length)) else . end) as $nodePad
          | (.peer | if length < 22 then . + (" " * (22 - length)) else . end) as $peerPad
          | "\($nodePad) -> \($peerPad) state=\(.st) hs=\(fmt_age(.hs)) ep=\(.ep) rx=\(fmt_bytes(.rx)) tx=\(fmt_bytes(.tx))"
        end
    )
'
