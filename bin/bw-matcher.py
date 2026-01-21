#!/usr/bin/env python3
"""
Bulk-update Bitwarden login URI match detection for items whose URI host matches one of your domains.

Typical use case:
- Keep Bitwarden default behavior for random internet sites
- Force Host/Exact match for your own subdomains so credentials don't "bleed" across services

Prereqs:
- Bitwarden CLI installed: bw
- Vault unlocked in this shell:
    export BW_SESSION="$(bw unlock --raw)"
  (or use `bw login` then `bw unlock --raw`)

Notes:
- Bitwarden match values (per Bitwarden CLI docs):
    Domain=0, Host=1, StartsWith=2, Exact=3, Regex=4, Never=5
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass
from typing import Any, Iterable
from urllib.parse import urlparse


MATCH_MAP = {
    "domain": 0,
    "host": 1,
    "startswith": 2,
    "exact": 3,
    "regex": 4,
    "never": 5,
}


@dataclass
class Change:
    item_id: str
    item_name: str
    uri: str
    old_match: Any
    new_match: int


def run_bw(args: list[str], stdin_text: str | None = None) -> str:
    p = subprocess.run(
        ["bw", *args],
        input=stdin_text,
        text=True,
        capture_output=True,
    )
    if p.returncode != 0:
        raise RuntimeError(
            f"bw {' '.join(args)} failed (exit {p.returncode}):\n{p.stderr.strip()}"
        )
    return p.stdout.strip()


def ensure_unlocked() -> None:
    out = run_bw(["status"])
    st = json.loads(out)
    status = st.get("status")
    if status != "unlocked":
        raise RuntimeError(
            f"Bitwarden status is '{status}'. Unlock first, e.g.:\n"
            f'  export BW_SESSION="$(bw unlock --raw)"'
        )


def normalize_domains(domains: Iterable[str]) -> list[str]:
    # Store as lowercase, no trailing dot.
    out: list[str] = []
    for d in domains:
        d = d.strip().lower().rstrip(".")
        if not d:
            continue
        out.append(d)
    return sorted(set(out), key=len, reverse=True)  # longer first


def host_from_uri(uri: str) -> str | None:
    uri = uri.strip()
    if not uri:
        return None

    # Bitwarden URIs may be stored without scheme, e.g. "grafana.example.com"
    # urlparse treats that as path unless we add a scheme.
    parsed = urlparse(uri if "://" in uri else f"https://{uri}")
    host = parsed.hostname
    if not host:
        return None
    return host.lower().rstrip(".")


def host_matches_domains(host: str, domains: list[str]) -> bool:
    # Match exact domain or any subdomain of it.
    # e.g. host=grafana.example.com matches domain=example.com
    for d in domains:
        if host == d or host.endswith("." + d):
            return True
    return False


def list_items(search: str | None = None) -> list[dict[str, Any]]:
    args = ["list", "items"]
    if search:
        args += ["--search", search]
    out = run_bw(args)
    return json.loads(out)


def encode_item(item: dict[str, Any]) -> str:
    # bw encode expects JSON on stdin and returns encoded payload
    return run_bw(["encode"], stdin_text=json.dumps(item))


def edit_item(item_id: str, item: dict[str, Any]) -> None:
    encoded = encode_item(item)
    _ = run_bw(["edit", "item", item_id], stdin_text=encoded)


def process_items(
    items: list[dict[str, Any]],
    domains: list[str],
    target_match: int,
    *,
    force: bool,
) -> tuple[list[Change], list[dict[str, Any]]]:
    changes: list[Change] = []
    updated_items: list[dict[str, Any]] = []

    for it in items:
        if it.get("type") != 1:  # 1 == Login items
            continue

        login = it.get("login") or {}
        uris = login.get("uris") or []
        if not isinstance(uris, list) or not uris:
            continue

        item_changed = False
        for u in uris:
            if not isinstance(u, dict):
                continue
            uri_val = u.get("uri") or ""
            host = host_from_uri(uri_val)
            if not host:
                continue
            if not host_matches_domains(host, domains):
                continue

            old = u.get("match")  # may be null/None => default (usually Domain)
            # Only change if:
            # - force, OR
            # - match unset/None, OR
            # - currently Domain(0) (broad matching)
            if force or old is None or old == 0:
                if old != target_match:
                    u["match"] = target_match
                    item_changed = True
                    changes.append(
                        Change(
                            item_id=it.get("id", ""),
                            item_name=it.get("name", "(no name)"),
                            uri=str(uri_val),
                            old_match=old,
                            new_match=target_match,
                        )
                    )

        if item_changed:
            updated_items.append(it)

    return changes, updated_items


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Bulk-update Bitwarden URI match detection for items whose URI host matches specified domains."
    )
    ap.add_argument(
        "--domains",
        required=True,
        help="Comma-separated list of domains (e.g. 'example.com,example.net,home.arpa')",
    )
    ap.add_argument(
        "--match",
        default="host",
        choices=sorted(MATCH_MAP.keys()),
        help="Target match detection for matching URIs (default: host).",
    )
    ap.add_argument(
        "--search",
        default=None,
        help="Optional bw --search filter to limit scanned items (faster on big vaults).",
    )
    ap.add_argument(
        "--force",
        action="store_true",
        help="Also change URIs even if their match is already non-Domain (overrides per-item customization).",
    )
    ap.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would change but do not edit anything.",
    )

    args = ap.parse_args()
    domains = normalize_domains(args.domains.split(","))
    target_match = MATCH_MAP[args.match]

    try:
        ensure_unlocked()
        items = list_items(search=args.search)
        changes, updated_items = process_items(
            items, domains, target_match, force=args.force
        )

        if not changes:
            print("No changes needed.")
            return 0

        print(f"Planned changes: {len(changes)}")
        for c in changes[:200]:
            print(
                f"- {c.item_name} ({c.item_id}): URI '{c.uri}' match {c.old_match} -> {c.new_match}"
            )
        if len(changes) > 200:
            print(f"... ({len(changes) - 200} more)")

        if args.dry_run:
            print("Dry-run: no items edited.")
            return 0

        # Deduplicate item IDs to avoid multiple edits per item
        to_update = {}
        for it in updated_items:
            item_id = it.get("id")
            if item_id:
                to_update[item_id] = it

        print(f"Editing items: {len(to_update)}")
        for item_id, it in to_update.items():
            edit_item(item_id, it)

        print("Done.")
        return 0

    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
