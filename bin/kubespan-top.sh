#!/usr/bin/env bash
set -euo pipefail

# One-page KubeSpan overview using all nodes from the active talosctl config (TALOSCONFIG respected).
# Requires: talosctl, jq (works on jq 1.6+)

tmp_peer="$(mktemp)"
tmp_ep="$(mktemp)"
tmp_spec="$(mktemp)"
tmp_host="$(mktemp)"
tmp_perr="$(mktemp)"
tmp_eerr="$(mktemp)"
tmp_serr="$(mktemp)"
tmp_herr="$(mktemp)"
trap 'rm -f "$tmp_peer" "$tmp_ep" "$tmp_spec" "$tmp_host" "$tmp_perr" "$tmp_eerr" "$tmp_serr" "$tmp_herr"' EXIT

NODES_CSV=$(talosctl config info -o json | jq -r '.nodes | unique | join(",")')
if [ -z "$NODES_CSV" ]; then
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

# Fetch each resource type; runs concurrently so an unreachable node's dial
# timeout is paid once (in parallel) rather than stacking across calls.
# $1 = resource type, $2 = output file, $3 = stderr capture file
fetch() {
    { talosctl get "$1" --nodes "$NODES_CSV" -o json 2>"$3" || true; } |
        jq -cs "$normalize_to_array" >"$2" || echo '[]' >"$2"
}

fetch kubespanpeerstatuses "$tmp_peer" "$tmp_perr" &
fetch kubespanendpoints    "$tmp_ep"   "$tmp_eerr" &
fetch kubespanpeerspecs    "$tmp_spec" "$tmp_serr" &
fetch hostname             "$tmp_host" "$tmp_herr" &
wait

# Flag config nodes talosctl could not reach (ground-truth from its dial errors).
unreachable=$(grep -hoE 'dial tcp [0-9.]+:50000' "$tmp_perr" "$tmp_eerr" "$tmp_serr" "$tmp_herr" 2>/dev/null |
    awk '{print $3}' | sed 's/:50000//' | sort -u | paste -sd, -)
[ -n "$unreachable" ] && echo "WARNING: no data from config nodes: $unreachable" >&2

now_epoch="$(date +%s)"

jq -rn --argjson NOW "$now_epoch" --slurpfile peers "$tmp_peer" --slurpfile eps "$tmp_ep" --slurpfile specs "$tmp_spec" --slurpfile hosts "$tmp_host" '
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

  | "KubeSpan overview (all TALOSCONFIG nodes)"
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
            ($e
              | map(select((.node // .metadata.labels["talos.dev/nodename"] // .metadata.hostname // .metadata.node // .metadata.id) == $row.n))
              | length
            ) | tostring
          )
    )

  , ""
  , "Endpoint details per peer"
  , "-------------------------"
  , "PEER                   CURRENT ENDPOINT             AVAILABLE ENDPOINTS"
  , (
      # Get unique peers with their endpoint info (deduplicated by peer label)
      $p
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
