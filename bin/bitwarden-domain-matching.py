#!/usr/bin/env python3
"""
Bulk-update Bitwarden login URI match detection for items whose URI host matches your domain.

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
from datetime import datetime


MATCH_MAP = {
    "domain": 0,
    "host": 1,
    "startswith": 2,
    "exact": 3,
    "regex": 4,
    "never": 5,
}

MATCH_NAME_BY_CODE = {v: k for k, v in MATCH_MAP.items()}


@dataclass
class Change:
    item_id: str
    item_name: str
    uri: str
    old_match: Any
    new_match: int

@dataclass
class Stats:
    items_scanned: int = 0
    login_items: int = 0
    uris_scanned: int = 0
    uris_with_host: int = 0
    uris_matching_domains: int = 0
    uris_changed: int = 0
    items_changed: int = 0
    skipped_no_host: int = 0
    skipped_not_in_domain: int = 0
    skipped_already_target: int = 0
    skipped_non_domain_without_force: int = 0

def match_name(code: Any) -> str:
    if code is None:
        return "domain"  # default behavior equals Domain(0)
    try:
        return MATCH_NAME_BY_CODE.get(int(code), str(code))
    except Exception:
        return str(code)

def format_match(code: Any) -> str:
    if code is None:
        return "Default/Domain(0)"
    name = match_name(code)
    return f"{name.capitalize()}({code})"


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
    debug: bool = False,
) -> tuple[list[Change], list[dict[str, Any]], Stats, list[str]]:
    changes: list[Change] = []
    updated_items: list[dict[str, Any]] = []
    stats = Stats()
    logs: list[str] = []

    for it in items:
        stats.items_scanned += 1
        if it.get("type") != 1:  # 1 == Login items
            continue

        stats.login_items += 1
        login = it.get("login") or {}
        uris = login.get("uris") or []
        if not isinstance(uris, list) or not uris:
            continue

        item_changed = False
        for u in uris:
            stats.uris_scanned += 1
            if not isinstance(u, dict):
                continue
            uri_val = u.get("uri") or ""
            host = host_from_uri(uri_val)
            if not host:
                stats.skipped_no_host += 1
                if debug:
                    logs.append(f"skip:no_host item={it.get('id')} uri={uri_val!r}")
                continue
            stats.uris_with_host += 1
            if not host_matches_domains(host, domains):
                stats.skipped_not_in_domain += 1
                if debug:
                    logs.append(f"skip:not_in_domain item={it.get('id')} host={host}")
                continue
            stats.uris_matching_domains += 1

            old = u.get("match")  # may be null/None => default (usually Domain)
            # Only change if force or old is None/Domain(0). If already equals target, skip.
            if not (force or old is None or old == 0):
                stats.skipped_non_domain_without_force += 1
                if debug:
                    logs.append(
                        f"skip:non_domain_without_force item={it.get('id')} uri={uri_val!r} old={match_name(old)}"
                    )
                continue
            if old == target_match:
                stats.skipped_already_target += 1
                if debug:
                    logs.append(
                        f"skip:already_target item={it.get('id')} uri={uri_val!r} target={match_name(target_match)}"
                    )
                continue

            u["match"] = target_match
            item_changed = True
            stats.uris_changed += 1
            changes.append(
                Change(
                    item_id=it.get("id", ""),
                    item_name=it.get("name", "(no name)"),
                    uri=str(uri_val),
                    old_match=old,
                    new_match=target_match,
                )
            )
            if debug:
                logs.append(
                    f"change item={it.get('id')} uri={uri_val!r} {match_name(old)}->{match_name(target_match)}"
                )

        if item_changed:
            updated_items.append(it)
            stats.items_changed += 1

    return changes, updated_items, stats, logs


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Bulk-update Bitwarden URI match detection for items whose URI host matches the specified domain."
    )
    ap.add_argument(
        "--domain",
        required=True,
        help="Single domain to match (e.g. 'example.com').",
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
        "--do-it",
        action="store_true",
        help="Apply the planned changes (default is dry-run).",
    )
    # Note: removed --verbose; summary and details are always shown in human output.
    ap.add_argument(
        "--json",
        action="store_true",
        help="Emit a JSON report of planned/applied changes and stats (suppresses human-readable output).",
    )
    ap.add_argument(
        "--debug",
        action="store_true",
        help="Print per-URI decision reasons; in --json mode include them in debug_logs.",
    )
    ap.add_argument(
        "--yes",
        action="store_true",
        help="Do not prompt for confirmation when applying changes.",
    )
    ap.add_argument(
        "--confirm-threshold",
        type=int,
        default=25,
        help="If applying and number of items exceeds this, prompt to confirm unless --yes (default: 25).",
    )
    ap.add_argument(
        "--write-plan",
        metavar="PATH",
        help="Write the planned changes and item payloads to PATH (JSON).",
    )
    ap.add_argument(
        "--apply-plan",
        metavar="PATH",
        help="Apply a previously written plan at PATH. Other selection flags are ignored.",
    )

    args = ap.parse_args()
    # If applying a saved plan, skip domain normalization and scanning
    if args.apply_plan and args.write_plan:
        ap.error("--apply-plan and --write-plan are mutually exclusive")

    # Special path: apply plan
    if args.apply_plan:
        ensure_unlocked()
        with open(args.apply_plan, "r", encoding="utf-8") as f:
            plan = json.load(f)
        domain = plan.get("domain")
        target_match = plan.get("target_match", {}).get("code")
        target_match_name = match_name(target_match)
        planned_changes = plan.get("planned_changes", [])
        items_to_edit_map = plan.get("item_map") or {}
        edited_item_ids: list[str] = []

        if args.json:
            applied = False
            if args.do_it:
                count_items = len(items_to_edit_map)
                if count_items > args.confirm_threshold and not args.yes:
                    # Still ask for confirmation in JSON mode
                    print(json.dumps({
                        "error": "confirmation_required",
                        "message": f"About to edit {count_items} items; re-run with --yes to confirm.",
                        "count": count_items
                    }))
                    return 2
                for item_id, it in items_to_edit_map.items():
                    edit_item(item_id, it)
                    edited_item_ids.append(item_id)
                applied = True
            report = {
                "domain": domain,
                "target_match": {"code": target_match, "name": target_match_name},
                "dry_run": not args.do_it,
                "applied": applied,
                "planned_changes_count": len(planned_changes),
                "planned_changes": planned_changes,
                "edited_items_count": len(set(edited_item_ids)) if applied else 0,
                "edited_item_ids": list(sorted(set(edited_item_ids))) if applied else [],
            }
            print(json.dumps(report, indent=2 if args.verbose else None))
            return 0 if applied or not planned_changes else 2

        # Human readable
        print(f"Planned changes (from plan): {len(planned_changes)} URIs across {len(items_to_edit_map)} items")
        for c in planned_changes:
            old = c.get("old_match", {})
            new = c.get("new_match", {})
            old_str = f"{str(old.get('name') or match_name(old.get('code'))).capitalize()}({old.get('code')})" if old else str(old)
            if old.get("code") is None:
                old_str = "Default/Domain(0)"
            new_str = f"{str(new.get('name') or match_name(new.get('code'))).capitalize()}({new.get('code')})"
            print(f"- {c.get('item_name')} ({c.get('item_id')}): URI '{c.get('uri')}' match {old_str} -> {new_str}")

        if not args.do_it:
            print("Dry-run: plan not applied. Use --do-it to edit items.")
            return 0 if not planned_changes else 2

        count_items = len(items_to_edit_map)
        if count_items > args.confirm_threshold and not args.yes:
            resp = input(f"About to edit {count_items} items. Proceed? [y/N] ").strip().lower()
            if resp not in ("y", "yes"):
                print("Aborted by user.")
                return 1

        print(f"Editing items: {count_items} (from {len(planned_changes)} URI updates)")
        for item_id, it in items_to_edit_map.items():
            edit_item(item_id, it)
        print("Done.")
        return 0

    # Normal scan path
    # Enforce single-domain input; reject comma-separated lists
    raw_domains = [s for s in args.domain.split(",") if s.strip()]
    domains = normalize_domains(raw_domains)
    if len(domains) != 1:
        ap.error(
            f"Exactly one domain must be provided via --domain; got: {raw_domains}"
        )
    target_match = MATCH_MAP[args.match]
    target_match_name = match_name(target_match)

    try:
        ensure_unlocked()
        items = list_items(search=args.search)
        if not args.json and domains:
            print(
                f"Domain: {domains[0]} | Target match: {format_match(target_match)} | "
                f"force: {args.force} | search: {args.search or '-'}"
            )
        changes, updated_items, stats, logs = process_items(
            items, domains, target_match, force=args.force, debug=args.debug
        )

        if not changes:
            if args.json:
                report = {
                    "domain": domains[0] if domains else None,
                    "target_match": {"code": target_match, "name": target_match_name},
                    "search": args.search,
                    "force": args.force,
                    "dry_run": not args.do_it,
                    "applied": False,
                    "planned_changes_count": 0,
                    "planned_changes": [],
                    "stats": vars(stats),
                    "debug_logs": logs if args.debug else [],
                }
                print(json.dumps(report))
                return 0
            print("No changes needed.")
            return 0

        # JSON report path (dry-run or apply)
        if args.json:
            report_changes = [
                {
                    "item_id": c.item_id,
                    "item_name": c.item_name,
                    "uri": c.uri,
                    "old_match": {"code": c.old_match, "name": match_name(c.old_match)},
                    "new_match": {"code": c.new_match, "name": match_name(c.new_match)},
                }
                for c in changes
            ]
            applied = False
            edited_item_ids: list[str] = []
            if args.do_it:
                to_update = {}
                for it in updated_items:
                    item_id = it.get("id")
                    if item_id:
                        to_update[item_id] = it
                if len(to_update) > args.confirm_threshold and not args.yes:
                    print(json.dumps({
                        "error": "confirmation_required",
                        "message": f"About to edit {len(to_update)} items; re-run with --yes to confirm.",
                        "count": len(to_update)
                    }))
                    return 2
                for item_id, it in to_update.items():
                    edit_item(item_id, it)
                    edited_item_ids.append(item_id)
                applied = True
            report = {
                "domain": domains[0],
                "target_match": {"code": target_match, "name": target_match_name},
                "search": args.search,
                "force": args.force,
                "dry_run": not args.do_it,
                "applied": applied,
                "planned_changes_count": len(changes),
                "planned_changes": report_changes,
                "edited_items_count": len(set(edited_item_ids)) if applied else 0,
                "edited_item_ids": list(sorted(set(edited_item_ids))) if applied else [],
                "stats": vars(stats),
                "debug_logs": logs if args.debug else [],
                "items_to_edit_count": stats.items_changed,
                "uri_changes_count": len(changes),
            }
            print(json.dumps(report))
            return 0 if applied or not changes else 2

        # Human-readable output
        print(f"Planned changes: {len(changes)} URIs across {stats.items_changed} items")
        for c in changes:
            print(
                f"- {c.item_name} ({c.item_id}): URI '{c.uri}' match {format_match(c.old_match)} -> {format_match(c.new_match)}"
            )
        # Summary and details (always printed)
        print(
            f"Summary: items scanned={stats.items_scanned}, login items={stats.login_items}, "
            f"uris scanned={stats.uris_scanned}, matched={stats.uris_matching_domains}, changed={stats.uris_changed}"
        )
        print(
            f"Details: skipped_no_host={stats.skipped_no_host}, skipped_not_in_domain={stats.skipped_not_in_domain}, "
            f"skipped_non_domain_without_force={stats.skipped_non_domain_without_force}, skipped_already_target={stats.skipped_already_target}"
        )
        if args.debug and logs:
            print("Debug:")
            for line in logs:
                print(f"  {line}")

        if not args.do_it:
            print("Dry-run: no items edited. Use --do-it to apply changes.")
            # Optionally write plan on dry-run
            if args.write_plan:
                # Deduplicate item IDs to avoid multiple edits per item
                to_update: dict[str, dict[str, Any]] = {}
                for it in updated_items:
                    item_id = it.get("id")
                    if item_id:
                        to_update[item_id] = it
                plan_payload = {
                    "version": 1,
                    "generated_at": datetime.utcnow().isoformat() + "Z",
                    "domain": domains[0],
                    "target_match": {"code": target_match, "name": target_match_name},
                    "search": args.search,
                    "force": args.force,
                    "planned_changes_count": len(changes),
                    "planned_changes": [
                        {
                            "item_id": c.item_id,
                            "item_name": c.item_name,
                            "uri": c.uri,
                            "old_match": {"code": c.old_match, "name": match_name(c.old_match)},
                            "new_match": {"code": c.new_match, "name": match_name(c.new_match)},
                        }
                        for c in changes
                    ],
                    # Map for application: id -> full updated item object
                    "item_map": {iid: it for iid, it in to_update.items()},
                }
                with open(args.write_plan, "w", encoding="utf-8") as f:
                    json.dump(plan_payload, f, indent=2)
                print(f"Wrote plan to {args.write_plan}")
            return 0 if not changes else 2

        # Deduplicate item IDs to avoid multiple edits per item
        to_update = {}
        for it in updated_items:
            item_id = it.get("id")
            if item_id:
                to_update[item_id] = it

        # If a lot of items will be edited, confirm unless --yes
        if len(to_update) > args.confirm_threshold and not args.yes:
            resp = input(f"About to edit {len(to_update)} items. Proceed? [y/N] ").strip().lower()
            if resp not in ("y", "yes"):
                print("Aborted by user.")
                return 1

        print(f"Editing items: {len(to_update)} (from {len(changes)} URI updates)")
        for item_id, it in to_update.items():
            edit_item(item_id, it)

        print("Done.")
        return 0

    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
