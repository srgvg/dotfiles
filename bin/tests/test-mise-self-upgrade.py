"""Offline failure/undo tests. Real candidate validation is `mise-self status --verify`."""
import importlib.machinery
import importlib.util
import io
import json
import os
import shutil
import subprocess
import tempfile
import time
import unittest
from contextlib import redirect_stdout
from datetime import UTC, datetime, timedelta
from pathlib import Path
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1] / "mise-self"
loader = importlib.machinery.SourceFileLoader("mise_guard", str(SOURCE))
spec = importlib.util.spec_from_loader(loader.name, loader)
mod = importlib.util.module_from_spec(spec)
loader.exec_module(mod)
NOW = datetime(2026, 10, 17, tzinfo=UTC)


class ReleaseAge(unittest.TestCase):
    def release(self, age):
        return {"tag_name": "v2026.10.13", "published_at": (NOW - age).isoformat(),
                "draft": False, "prerelease": False}

    def test_full_seven_day_boundary(self):
        mod.release_allowed(self.release(timedelta(days=7)), NOW)
        with self.assertRaises(mod.Refused):
            mod.release_allowed(self.release(timedelta(days=7, seconds=-1)), NOW)

    def test_future_draft_prerelease_and_bad_version_refuse(self):
        for change in ({"published_at": (NOW + timedelta(days=1)).isoformat()},
                       {"draft": True}, {"prerelease": True}, {"tag_name": "latest"},
                       {"tag_name": "v2026.10.13-rc1"}):
            with self.subTest(change=change), self.assertRaises(mod.Refused):
                mod.release_allowed(self.release(timedelta(days=8)) | change, NOW)


class Discovery(unittest.TestCase):
    def discover(self, releases):
        with patch.object(mod.urllib.request, "urlopen",
                          return_value=io.BytesIO(json.dumps(releases).encode())):
            return mod.discover_releases("2026.9.1", NOW)

    def test_sort_filter_and_full_age_boundary(self):
        stable = {"published_at": (NOW - timedelta(days=7)).isoformat(),
                  "draft": False, "prerelease": False}
        rows = self.discover([
            stable | {"tag_name": "v2026.10.2"},
            stable | {"tag_name": "v2026.10.11", "published_at": NOW.isoformat()},
            stable | {"tag_name": "v2026.10.10"},
            stable | {"tag_name": "v2026.11.1", "draft": True},
            stable | {"tag_name": "v2026.11.2", "prerelease": True},
            stable | {"tag_name": "v2026.11.3-rc1"},
            stable | {"tag_name": "nightly"},
            stable | {"tag_name": "v2026.9.1"},
            stable | {"tag_name": "v2026.8.1"},
        ])
        self.assertEqual([(v, eligible) for v, eligible, _ in rows],
                         [("2026.10.11", False), ("2026.10.10", True), ("2026.10.2", True)])
        self.assertIn("eligible at", rows[0][2])

    def test_no_newer_and_network_failure_are_distinct(self):
        self.assertEqual(self.discover([]), [])
        with (patch.object(mod.urllib.request, "urlopen", side_effect=OSError("offline")),
              self.assertRaisesRegex(OSError, "offline")):
            mod.discover_releases("2026.9.1", NOW)

    def run_main(self, *argv, entry="main"):
        with (patch.object(mod.sys, "argv", list(argv)), patch.object(mod, "Guard") as guard):
            guard.return_value.home = Path("/home/test")
            return getattr(mod, entry)(), guard.return_value

    def test_status_only_reads(self):
        code, guard = self.run_main("mise-self", "status")
        self.assertEqual(code, 0)
        guard.status.assert_called_once_with(False, [Path("/home/test/etc")])
        guard.upgrade.assert_not_called()

    def test_status_verify_flag_is_passed_on(self):
        _, guard = self.run_main("mise-self", "status", "--verify")
        guard.status.assert_called_once_with(True, [Path("/home/test/etc")])

    def test_sync_follows_the_pin_and_never_picks_a_version(self):
        code, guard = self.run_main("mise-self", "sync")
        self.assertEqual(code, 0)
        guard.sync.assert_called_once_with([Path("/home/test/etc")])
        guard.update.assert_not_called()

    def test_bare_update_lets_the_guard_choose(self):
        _, guard = self.run_main("mise-self", "update")
        guard.update.assert_called_once_with(None, False, [Path("/home/test/etc")])

    def test_update_with_version_and_dry_run(self):
        _, guard = self.run_main("mise-self", "update", "2026.10.10")
        guard.update.assert_called_once_with("2026.10.10", False, [Path("/home/test/etc")])
        _, guard = self.run_main("mise-self", "update", "v2026.10.10", "--dry-run")
        guard.update.assert_called_once_with("2026.10.10", True, [Path("/home/test/etc")])

    def test_bare_undo_restores_the_newest_promotion(self):
        _, guard = self.run_main("mise-self", "undo")
        guard.undo_latest.assert_called_once_with()
        guard.rollback.assert_not_called()

    def test_undo_list_and_undo_with_id(self):
        _, guard = self.run_main("mise-self", "undo", "--list")
        guard.rollback.assert_called_once_with(None)
        _, guard = self.run_main("mise-self", "undo", "20261017T120000Z-1234abcd")
        guard.rollback.assert_called_once_with("20261017T120000Z-1234abcd")

    def test_old_verbs_are_gone(self):
        for verb in ("check", "apply", "verify", "maintain", "rollback"):
            with (self.subTest(verb=verb), patch.object(mod.sys, "argv", ["mise-self", verb]),
                  patch.object(mod, "Guard"), patch.object(mod.sys, "stderr", io.StringIO()),
                  self.assertRaises(SystemExit) as raised):
                mod.main()
            self.assertEqual(raised.exception.code, 2)

    def test_mise_tools_update_syncs_then_maintains(self):
        calls = []
        with (patch.object(mod.sys, "argv", ["mise-tools", "update"]), patch.object(mod, "Guard") as guard):
            guard.return_value.home = Path("/home/test")
            guard.return_value.sync.side_effect = lambda *a: calls.append("sync")
            guard.return_value.maintain.side_effect = lambda *a: calls.append("maintain")
            self.assertEqual(mod.main_tools(), 0)
        self.assertEqual(calls, ["sync", "maintain"])

    def test_mise_tools_stops_when_sync_refuses(self):
        with (patch.object(mod.sys, "argv", ["mise-tools", "update"]), patch.object(mod, "Guard") as guard,
              patch.object(mod.sys, "stderr", io.StringIO())):
            guard.return_value.home = Path("/home/test")
            guard.return_value.sync.side_effect = mod.Refused("no")
            self.assertEqual(mod.main_tools(), 1)
            guard.return_value.maintain.assert_not_called()


class ProbeComparison(unittest.TestCase):
    def probe(self, **overrides):
        base = {
            "tools": {"node": [("24.0.0", "/installs/node/24")]},
            "env": {"GOBIN": "/home/user/.local/bin"},
            "smoke": "ok\n",
            "winners": {"node": "/installs/node/24/bin/node",
                        "grok": "/installs/http-grok/1.0.62/grok"},
            "projects": {"/home/user/etc": {
                "tools": {},
                "tasks": [{"name": "etc:status", "run": ["./status"], "description": "status",
                           "source": "/home/user/etc/mise-tasks/etc/status"}],
            }},
        }
        base.update(overrides)
        return base

    def test_same_file_and_empty_task_fields_pass(self):
        old = self.probe()
        new = self.probe()
        new["winners"] = dict(new["winners"])
        new["winners"]["pnpm"] = "/installs/npm-pnpm/11.20.0/node_modules/.bin/pnpm"
        tasks = new["projects"]["/home/user/etc"]["tasks"]
        tasks[0] = dict(tasks[0])
        tasks[0]["config_sources"] = ["/home/user/etc/mise-tasks/etc/status"]
        tasks[0]["secrets"] = []
        tasks[0]["daemons"] = False
        self.assertEqual(mod.compare_probes(old, new), [
            "PATH gained commands the installed mise did not expose: pnpm"])

    def test_shim_instead_of_the_direct_file_is_reported(self):
        new = self.probe()
        new["winners"] = dict(new["winners"])
        new["winners"]["grok"] = "shim"
        self.assertEqual(mod.compare_probes(self.probe(), new), [
            "PATH prefers the mise shim for: grok"])

    def test_tool_the_candidate_cannot_see_is_a_reinstall_note_not_a_refusal(self):
        # mise 2026.10.25 did not recognise 2026.10.17's `~uv~<hash>` pipx installs.
        old = self.probe(tools={"node": [("24.0.0", "/installs/node/24")],
                                "pipx:omnigent": [("0.21.0", "/installs/pipx-omnigent/0.21.0~uv~ab")]})
        new = self.probe(reinstall=["pipx:omnigent"])
        note = ("the candidate does not recognise these installations and mise install "
                "will redo them after promotion: pipx:omnigent")
        self.assertEqual(mod.compare_probes(old, new), [note])

    def test_doctor_accepts_only_the_reinstall_tools_as_its_problems(self):
        text = "warnings...\n\n1 problem found:\n\n1. tool pipx:omnigent@0.21.0 is not installed, install with `mise install`\n"
        self.assertTrue(mod.doctor_healthy("No problems found\n", set()))
        self.assertTrue(mod.doctor_healthy(text, {"pipx:omnigent"}))
        self.assertFalse(mod.doctor_healthy(text, set()))
        self.assertFalse(mod.doctor_healthy(text.replace("1 problem", "2 problems"), {"pipx:omnigent"}))
        self.assertFalse(mod.doctor_healthy("1 problem found:\n\n1. something else broke\n", {"pipx:omnigent"}))

    def test_a_tool_that_vanishes_without_a_reinstall_mark_still_refuses(self):
        old = self.probe(tools={"node": [("24.0.0", "/installs/node/24")],
                                "pipx:omnigent": [("0.21.0", "/installs/pipx-omnigent/0.21.0")]})
        with self.assertRaisesRegex(mod.Refused, "changed tools"):
            mod.compare_probes(old, self.probe())

    def test_different_file_dropped_command_and_real_task_change_refuse(self):
        moved = self.probe()
        moved["winners"] = dict(moved["winners"])
        moved["winners"]["grok"] = "/installs/http-grok/9.9.9/grok"
        with self.assertRaisesRegex(mod.Refused, "which file"):
            mod.compare_probes(self.probe(), moved)
        dropped = self.probe()
        dropped["winners"] = {"node": dropped["winners"]["node"]}
        with self.assertRaisesRegex(mod.Refused, "dropped PATH commands: grok"):
            mod.compare_probes(self.probe(), dropped)
        changed = self.probe()
        changed["projects"] = {"/home/user/etc": {
            "tools": {},
            "tasks": [{"name": "etc:status", "run": ["./other"], "description": "status",
                       "source": "/home/user/etc/mise-tasks/etc/status"}],
        }}
        with self.assertRaisesRegex(mod.Refused, "changed tasks"):
            mod.compare_probes(self.probe(), changed)
        secret = self.probe()
        secret["projects"] = {"/home/user/etc": {
            "tools": {},
            "tasks": [{"name": "etc:status", "run": ["./status"], "description": "status",
                       "source": "/home/user/etc/mise-tasks/etc/status",
                       "secrets": ["DEPLOY_KEY"]}],
        }}
        with self.assertRaisesRegex(mod.Refused, "gained behavior fields: secrets"):
            mod.compare_probes(self.probe(), secret)


class Transaction(unittest.TestCase):
    def setUp(self):
        self.enterContext(redirect_stdout(io.StringIO()))
        # Require a disk-backed scratch parent supplied by the test invocation.
        self.tmp = tempfile.TemporaryDirectory(dir=os.environ["MISE_GUARD_TEST_ROOT"],
                                             prefix="guard-tests-")
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.guard = mod.Guard(self.home)
        for p in (self.guard.binary.parent, self.guard.pin.parent,
                  self.guard.config, self.guard.data / "shims"):
            p.mkdir(parents=True, exist_ok=True)
        self.guard.binary.write_bytes(b"old mise")
        self.guard.binary.chmod(0o755)
        self.guard.pin.write_text("# other pins survive\nMISE_VERSION=v2026.5.18\nOTHER=1\n")
        self.guard.config.joinpath("config.toml").write_text('[tools]\nnode = "24"\n')
        self.guard.config.joinpath("mise.lock").write_text("old lockfile\n")
        self.guard.data.joinpath("shims/node").symlink_to(self.guard.binary)
        self.root = self.guard.state / "20261017T120000Z-1234abcd"
        self.root.mkdir()
        self.stage = self.home / "work"
        self.stage.joinpath("candidate").mkdir(parents=True)
        self.stage.joinpath("candidate/mise").write_bytes(b"new mise")
        self.before = self.guard.fingerprints()

    def promote(self):
        self.guard.promote(self.root, self.stage, "2026.10.13", self.before, [])

    def transaction(self):
        return json.loads(self.root.joinpath("transaction.json").read_text())

    def assert_restored(self):
        self.assertEqual(self.guard.fingerprints(), self.before)
        self.assertEqual(self.transaction()["status"], "rolled_back")

    def test_success_and_manual_rollback(self):
        with patch.object(self.guard, "probe"):
            self.promote()
        self.assertEqual(self.guard.binary.read_bytes(), b"new mise")
        self.assertEqual(self.guard.pinned(), "2026.10.13")
        self.assertIn("OTHER=1", self.guard.pin.read_text())
        self.assertEqual(self.transaction()["status"], "complete")
        self.guard.rollback(self.root.name)
        self.assert_restored()

    def test_rollback_listing_is_read_only_and_reports_readiness(self):
        output = io.StringIO()
        with redirect_stdout(output):
            self.guard.rollback(None)
        self.assertIn("No saved promotions", output.getvalue())
        with patch.object(self.guard, "probe"):
            self.promote()
        for status in ("complete", "promoting", "rollback_failed", "rolled_back"):
            txn = self.transaction() | {"status": status}
            mod.save_json(self.root / "transaction.json", txn)
            before = mod.tree_digest(self.home)
            output = io.StringIO()
            with redirect_stdout(output):
                self.guard.rollback(None)
            self.assertEqual(mod.tree_digest(self.home), before)
            command = f"mise-self undo {self.root.name}"
            if status == "rolled_back":
                self.assertNotIn(command, output.getvalue())
                self.assertIn("Unavailable", output.getvalue())
            else:
                self.assertIn(command, output.getvalue())
                self.assertIn("Ready to restore 2026.5.18", output.getvalue())

    def test_rollback_listing_reports_later_edits_and_damaged_records(self):
        with patch.object(self.guard, "probe"):
            self.promote()
        broken = self.guard.state / "20261018T120000Z-1234abcd"
        broken.mkdir()
        broken.joinpath("transaction.json").write_text("broken json")
        self.guard.config.joinpath("config.toml").write_text("later work")
        output = io.StringIO()
        before = mod.tree_digest(self.home)
        with redirect_stdout(output):
            self.guard.rollback(None)
        self.assertEqual(mod.tree_digest(self.home), before)
        self.assertIn(broken.name, output.getvalue())
        self.assertIn(self.root.name, output.getvalue())
        self.assertIn("later work", output.getvalue())
        self.assertNotIn(f"mise-self undo {self.root.name}", output.getvalue())
        self.assertLess(output.getvalue().index(broken.name), output.getvalue().index(self.root.name))

    def test_pin_line_endings_and_other_values_survive(self):
        self.guard.pin.write_bytes(b"# pins\r\nMISE_VERSION=v2026.5.18\r\nOTHER=1\r\n")
        self.before = self.guard.fingerprints()
        with patch.object(self.guard, "probe"):
            self.promote()
        self.assertEqual(self.guard.pin.read_bytes(),
                         b"# pins\r\nMISE_VERSION=v2026.10.13\r\nOTHER=1\r\n")
        self.guard.rollback(self.root.name)
        self.assert_restored()

    def test_post_promotion_failure_rolls_back(self):
        with (patch.object(self.guard, "probe", side_effect=mod.Refused("bad shell")),
              self.assertRaisesRegex(mod.Refused, "bad shell")):
            self.promote()
        self.assert_restored()

    def test_interrupt_rolls_back(self):
        with (patch.object(self.guard, "probe", side_effect=KeyboardInterrupt),
              self.assertRaises(KeyboardInterrupt)):
            self.promote()
        self.assert_restored()

    def test_partial_binary_pin_write_rolls_back(self):
        real_write = mod.atomic_write
        failed = False
        def fail_pin_once(path, content, mode=0o600):
            nonlocal failed
            if path == self.guard.pin and not failed:
                failed = True
                raise OSError("disk write failure")
            return real_write(path, content, mode)
        with (patch.object(mod, "atomic_write", side_effect=fail_pin_once),
              self.assertRaisesRegex(OSError, "disk write failure")):
            self.promote()
        self.assert_restored()

    def test_concurrent_edit_before_promotion_refuses(self):
        self.guard.pin.write_text("MISE_VERSION=v2026.7.1\n")
        with self.assertRaisesRegex(mod.Refused, "changed during validation"):
            self.promote()
        self.assertEqual(self.guard.binary.read_bytes(), b"old mise")
        self.assertFalse(self.root.joinpath("transaction.json").exists())

    def test_rollback_refuses_later_config_or_pin_changes(self):
        with patch.object(self.guard, "probe"):
            self.promote()
        for kind in ("config", "pin", "binary", "shims"):
            with self.subTest(kind=kind):
                target = {"config": self.guard.config / "config.toml",
                          "pin": self.guard.pin, "binary": self.guard.binary,
                          "shims": self.guard.data / "shims/extra"}[kind]
                original = target.read_bytes() if target.exists() else None
                target.write_bytes(b"later user work")
                with self.assertRaisesRegex(mod.Refused, "later work"):
                    self.guard.rollback(self.root.name)
                self.assertEqual(target.read_bytes(), b"later user work")
                if original is None:
                    target.unlink()
                else:
                    target.write_bytes(original)
        self.guard.rollback(self.root.name)

    def test_corrupt_backup_refuses(self):
        with patch.object(self.guard, "probe"):
            self.promote()
        self.root.joinpath("mise.before").write_bytes(b"corrupted")
        with self.assertRaisesRegex(mod.Refused, "checksum"):
            self.guard.rollback(self.root.name)
        self.assertEqual(self.guard.binary.read_bytes(), b"new mise")

    def test_crash_record_blocks_maintenance_until_rollback(self):
        with patch.object(self.guard, "probe"):
            self.promote()
        txn = self.transaction()
        txn["status"] = "promoting"
        mod.save_json(self.root / "transaction.json", txn)
        # Simulate termination after installing the binary but before changing the pin.
        self.guard.pin.write_bytes(self.root.joinpath("versions.before").read_bytes())
        with self.assertRaisesRegex(mod.Refused, "unfinished promotion"):
            self.guard.pending()
        self.guard.rollback(self.root.name)
        self.assert_restored()
        self.guard.pending()

    def test_shared_lock_excludes_other_invocations(self):
        other = mod.Guard(self.home)
        with self.guard.locked(), self.assertRaisesRegex(mod.Refused, "already running"), other.locked():
            self.fail("second lock acquired")
        with other.locked():
            pass

    def test_bad_rollback_id_refuses(self):
        with self.assertRaises(mod.Refused):
            self.guard.rollback("../../etc")

    def test_timeout_terminates_child_commands(self):
        marker = self.home / "child-survived"
        with self.assertRaisesRegex(mod.Refused, "timed out"):
            self.guard.run(["/bin/sh", "-c", 'sleep 0.3; touch "$1"', "test", marker], timeout=.03)
        time.sleep(.4)
        self.assertFalse(marker.exists())

    def test_maintenance_stops_at_each_failed_step(self):
        for failed_step in ("install", "upgrade", "lock", "reshim", "doctor", "prune"):
            seen = []
            def run(command, seen=seen, failed_step=failed_step, **kwargs):
                self.assertEqual(kwargs["env"]["PATH"].split(":")[0], str(self.guard.data / "shims"))
                step = command[1] if command[0] == self.guard.binary else "prune"
                seen.append(step)
                if step == failed_step:
                    raise mod.Refused("expected failure")
                return ""
            with (self.subTest(step=failed_step),
                  patch.object(self.guard, "installed", return_value="2026.5.18"),
                  patch.object(self.guard, "run", side_effect=run), self.assertRaises(mod.Refused)):
                self.guard.maintain()
            self.assertEqual(seen[-1], failed_step)
            self.assertNotIn("self-update", seen)
            self.assertNotIn("plugins", seen)

    def test_maintenance_pin_mismatch_refuses_before_commands(self):
        with patch.object(self.guard, "installed", return_value="2026.9.1"):
            with (patch.object(self.guard, "run") as run,
                  self.assertRaisesRegex(mod.Refused, "mise-self sync")):
                self.guard.maintain()
            run.assert_not_called()

    def set_pin(self, version):
        self.guard.pin.write_text(f"MISE_VERSION=v{version}\n")
        self.before = self.guard.fingerprints()

    def test_sync_installs_the_pinned_version_when_the_pin_is_ahead(self):
        self.set_pin("2026.10.25")
        def stage(root):
            self.guard.work = self.stage
            return self.stage
        with patch.object(self.guard, "installed", return_value="2026.10.17"), \
             patch.object(mod, "fetch_release", return_value={"tag_name": "v2026.10.25"}) as fetch, \
             patch.object(self.guard, "stage", side_effect=stage), \
             patch.object(self.guard, "sandbox", return_value="2026.10.25 linux-x64"), \
             patch.object(self.guard, "validate"), \
             patch.object(self.guard, "install_missing"), \
             patch.object(self.guard, "promote") as promote:
            self.guard.sync([])
            fetch.assert_called_once_with("2026.10.25")
            promote.assert_called_once()
            self.assertEqual(promote.call_args.args[2], "2026.10.25")

    def upgrade_with_install_probe(self, action, version, pin):
        """Run upgrade() far enough to see whether `mise install` ran before staging."""
        self.set_pin(pin)
        order = []
        def run(command, **kwargs):
            order.append(" ".join(map(str, command[1:])))
            return ""
        def stage(root):
            order.append("stage")
            raise mod.Refused("stop after staging")
        with patch.object(self.guard, "installed", return_value="2026.10.17"), \
             patch.object(mod, "fetch_release", return_value={"tag_name": "v" + version}), \
             patch.object(self.guard, "run", side_effect=run), \
             patch.object(self.guard, "stage", side_effect=stage), \
             self.assertRaisesRegex(mod.Refused, "stop after staging"):
            self.guard.upgrade(action, version, [])
        return order

    def test_sync_and_update_repair_missing_tools_before_validating(self):
        # A `latest` tool whose newer release is not installed yet makes validation refuse,
        # and tool maintenance runs only after sync, so sync must install first.
        for action, version, pin in (("sync", "2026.10.25", "2026.10.25"),
                                     ("apply", "2026.10.20", "2026.10.17")):
            with self.subTest(action=action):
                order = self.upgrade_with_install_probe(action, version, pin)
                self.assertEqual(order, ["install --yes", "stage"])

    def test_promotion_is_followed_by_a_reinstall_when_the_candidate_asked_for_one(self):
        self.set_pin("2026.10.25")
        installs = []
        def stage(root):
            self.guard.work = self.stage
            return self.stage
        def validate(stage, projects):
            self.guard.reinstall = ["pipx:omnigent"]
        with patch.object(self.guard, "installed", return_value="2026.10.17"), \
             patch.object(mod, "fetch_release", return_value={"tag_name": "v2026.10.25"}), \
             patch.object(self.guard, "stage", side_effect=stage), \
             patch.object(self.guard, "sandbox", return_value="2026.10.25 linux-x64"), \
             patch.object(self.guard, "validate", side_effect=validate), \
             patch.object(self.guard, "install_missing", side_effect=lambda: installs.append(1)), \
             patch.object(self.guard, "promote") as promote:
            self.guard.sync([])
        promote.assert_called_once()
        # Once before staging (old binary), once after promotion (new binary).
        self.assertEqual(len(installs), 2)

    def test_no_second_install_when_nothing_needs_reinstalling(self):
        self.set_pin("2026.10.25")
        installs = []
        def stage(root):
            self.guard.work = self.stage
            return self.stage
        with patch.object(self.guard, "installed", return_value="2026.10.17"), \
             patch.object(mod, "fetch_release", return_value={"tag_name": "v2026.10.25"}), \
             patch.object(self.guard, "stage", side_effect=stage), \
             patch.object(self.guard, "sandbox", return_value="2026.10.25 linux-x64"), \
             patch.object(self.guard, "validate"), \
             patch.object(self.guard, "install_missing", side_effect=lambda: installs.append(1)), \
             patch.object(self.guard, "promote"):
            self.guard.sync([])
        self.assertEqual(len(installs), 1)

    def test_dry_run_and_verify_never_install_anything(self):
        order = self.upgrade_with_install_probe("check", "2026.10.20", "2026.10.17")
        self.assertEqual(order, ["stage"])

    def test_missing_tool_refusal_names_the_route(self):
        self.assertIn("mise install", mod.MISSING_HINT)

    def test_sync_with_matching_pin_does_nothing(self):
        self.set_pin("2026.10.17")
        output = io.StringIO()
        with patch.object(self.guard, "installed", return_value="2026.10.17"), \
             patch.object(self.guard, "stage") as stage, redirect_stdout(output):
            self.guard.sync([])
        stage.assert_not_called()
        self.assertIn("nothing to do", output.getvalue())

    def test_sync_refuses_when_installed_is_ahead_and_names_working_routes(self):
        self.set_pin("2026.5.18")
        with patch.object(self.guard, "installed", return_value="2026.10.17"), \
             patch.object(self.guard, "stage") as stage:
            with self.assertRaises(mod.Refused) as raised:
                self.guard.sync([])
            stage.assert_not_called()
        self.assertIn("mise-self undo", str(raised.exception))
        self.assertIn("MISE_VERSION=v2026.10.17", str(raised.exception))

    def test_update_refuses_on_pin_mismatch_with_the_route_that_works(self):
        self.set_pin("2026.10.25")
        with patch.object(self.guard, "installed", return_value="2026.10.17"), \
             patch.object(self.guard, "upgrade") as upgrade:
            with self.assertRaisesRegex(mod.Refused, "mise-self sync"):
                self.guard.update(None, False, [])
            upgrade.assert_not_called()

    def test_upgrade_refuses_on_pin_mismatch_with_the_route_that_works(self):
        self.set_pin("2026.10.25")
        with (patch.object(self.guard, "installed", return_value="2026.10.17"),
              self.assertRaisesRegex(mod.Refused, "mise-self sync")):
            self.guard.upgrade("apply", "2026.10.20", [])

    def releases(self, *rows):
        return patch.object(mod, "discover_releases", return_value=list(rows))

    def test_bare_update_takes_the_newest_eligible_release(self):
        self.set_pin("2026.10.17")
        with patch.object(self.guard, "installed", return_value="2026.10.17"), \
             self.releases(("2026.10.30", False, "younger"), ("2026.10.20", True, "ok"),
                           ("2026.10.19", True, "ok")), \
             patch.object(self.guard, "upgrade") as upgrade:
            self.guard.update(None, False, [])
            upgrade.assert_called_once_with("apply", "2026.10.20", [])

    def test_dry_run_validates_without_promoting(self):
        self.set_pin("2026.10.17")
        with patch.object(self.guard, "installed", return_value="2026.10.17"), \
             patch.object(self.guard, "upgrade") as upgrade:
            self.guard.update("2026.10.20", True, [])
            upgrade.assert_called_once_with("check", "2026.10.20", [])

    def test_update_with_nothing_eligible_says_so_and_changes_nothing(self):
        self.set_pin("2026.10.17")
        output = io.StringIO()
        with patch.object(self.guard, "installed", return_value="2026.10.17"), \
             self.releases(("2026.10.30", False, "younger than seven days")), \
             patch.object(self.guard, "upgrade") as upgrade, redirect_stdout(output):
            self.guard.update(None, False, [])
        upgrade.assert_not_called()
        self.assertIn("younger than seven days", output.getvalue())

    def status(self, installed, pin, *rows):
        self.set_pin(pin)
        output = io.StringIO()
        with patch.object(self.guard, "installed", return_value=installed), \
             self.releases(*rows), redirect_stdout(output):
            self.guard.status(False, [])
        return output.getvalue()

    def test_status_names_the_next_command_for_each_state(self):
        self.assertIn("mise-self sync", self.status("2026.10.17", "2026.10.25"))
        ahead = self.status("2026.10.25", "2026.10.17")
        self.assertIn("mise-self undo", ahead)
        self.assertIn("MISE_VERSION=v2026.10.25", ahead)
        self.assertIn("mise-self update", self.status("2026.10.17", "2026.10.17", ("2026.10.20", True, "ok")))
        self.assertIn("up to date", self.status("2026.10.17", "2026.10.17").lower())

    def test_status_never_claims_up_to_date_when_the_release_list_fails(self):
        self.set_pin("2026.10.17")
        output = io.StringIO()
        with patch.object(self.guard, "installed", return_value="2026.10.17"), \
             patch.object(mod, "discover_releases", side_effect=OSError("offline")), \
             redirect_stdout(output):
            self.guard.status(False, [])
        self.assertNotIn("up to date", output.getvalue().lower())
        self.assertIn("offline", output.getvalue())

    def test_undo_latest_restores_the_newest_promotion(self):
        with patch.object(self.guard, "probe"):
            self.promote()
        self.guard.undo_latest()
        self.assert_restored()

    def test_undo_latest_with_nothing_saved_says_so(self):
        output = io.StringIO()
        with redirect_stdout(output):
            self.guard.undo_latest()
        self.assertIn("No saved promotions", output.getvalue())

    def test_undo_latest_refuses_instead_of_falling_back_to_an_older_record(self):
        with patch.object(self.guard, "probe"):
            self.promote()
        self.guard.config.joinpath("config.toml").write_text("later work")
        with self.assertRaisesRegex(mod.Refused, "state changed"):
            self.guard.undo_latest()

    def test_failed_validation_never_promotes_and_cleans_stage(self):
        def stage(root):
            self.guard.work = self.stage
            return self.stage
        with patch.object(self.guard, "installed", return_value="2026.5.18"), \
             patch.object(self.guard, "stage", side_effect=stage), \
             patch.object(self.guard, "sandbox", return_value="2026.5.18 linux-x64"), \
             patch.object(self.guard, "validate", side_effect=mod.Refused("changed tools")), \
             patch.object(self.guard, "promote") as promote:
            with self.assertRaisesRegex(mod.Refused, "changed tools"):
                self.guard.upgrade("verify", None, [])
            promote.assert_not_called()
        self.assertEqual(self.guard.fingerprints(), self.before)
        self.assertFalse(self.stage.exists())

    def test_recent_explicit_version_refused_before_staging(self):
        with patch.object(self.guard, "installed", return_value="2026.5.18"), \
             patch.object(mod, "fetch_release", side_effect=mod.Refused("younger than seven days")), \
             patch.object(self.guard, "stage") as stage:
            with self.assertRaisesRegex(mod.Refused, "seven days"):
                self.guard.upgrade("apply", "2026.10.13", [])
            stage.assert_not_called()
        self.assertEqual(self.guard.fingerprints(), self.before)

    def test_wrapper_propagates_failure_even_in_conditional(self):
        source = SOURCE.with_name("update-tools").read_text()
        for function, command in (("get_mise_self", "mise-self"), ("get_mise_tools", "mise-tools")):
            start = source.index(f"{function}() {{")
            block = source[start:source.index("\n}", start) + 2]
            self.assertIn(f'"$HOME/bin/{command}"', block)
            block = block.replace(f'"$HOME/bin/{command}"', "fake_guard")
            p = subprocess.run(["/bin/bash", "--noprofile", "--norc", "-c",
                                "title() { :; }; fake_guard() { return 42; };\n" + block +
                                f"\nif {function}; then exit 99; else exit $?; fi"],
                               capture_output=True, check=False)
            with self.subTest(function=function):
                self.assertEqual(p.returncode, 42)

    def test_update_tools_has_no_component_named_plain_mise(self):
        source = SOURCE.with_name("update-tools").read_text()
        self.assertNotIn("\n        mise)\n", source)
        self.assertNotIn("get_mise() {", source)
        self.assertNotIn("    mise\n", source)

    def test_quick_mode_records_background_mise_failure(self):
        source = SOURCE.with_name("update-tools").read_text()
        start = source.index("update_quick() {")
        block = source[start:source.index("\n}", start) + 2]
        # Quick mode runs components in parallel. mise_self would race mise_tools for the shared
        # lock, and mise_tools already syncs first, so quick mode runs mise_tools only.
        stubs = "\n".join(f"get_{name}() {{ return 0; }}" for name in
                           ("downloads", "flatpak", "helm", "krew", "misc", "uv_tools", "bash_completions"))
        p = subprocess.run(["/bin/bash", "--noprofile", "--norc", "-c",
                            "set -u; FAILED_COMPONENTS=();\n" + stubs +
                            "\nget_mise_tools() { return 42; }; get_mise_self() { return 43; };\n" + block +
                            '\nupdate_quick; printf "%s\\n" "${FAILED_COMPONENTS[@]}"'],
                           capture_output=True, text=True, check=False)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(p.stdout, "mise_tools\n")


@unittest.skipUnless(os.environ.get("MISE_GUARD_INTEGRATION") == "1", "opt-in real isolation checks")
class Isolation(unittest.TestCase):
    def test_read_only_live_files_and_no_network(self):
        guard = mod.Guard()
        with guard.locked(), tempfile.TemporaryDirectory(
                dir=os.environ["MISE_GUARD_TEST_ROOT"], prefix="guard-isolation-") as tmp:
            root = Path(tmp)
            outside = root / "outside.txt"
            outside.write_text("keep me")
            stage = guard.stage(root)
            try:
                with self.assertRaises(mod.Refused):
                    guard.sandbox(stage, ["/bin/sh", "-c", 'echo changed > "$1"', "test", outside])
                self.assertEqual(outside.read_text(), "keep me")
                guard.sandbox(stage, ["/usr/bin/python3", "-c",
                    ('import socket; s=socket.socket(); s.settimeout(1); '
                     'assert s.connect_ex(("1.1.1.1", 443)) != 0')])
                # Exercise the post-promotion path without replacing the live executable.
                guard.probe(stage, guard.binary, [guard.home / "etc"])
            finally:
                shutil.rmtree(stage)

    @unittest.skipUnless(os.environ.get("MISE_GUARD_NETWORK_TEST") == "1", "opt-in signed download check")
    def test_signed_download_replaces_only_staged_copy(self):
        guard = mod.Guard()
        with guard.locked(), tempfile.TemporaryDirectory(
                dir=os.environ["MISE_GUARD_TEST_ROOT"], prefix="guard-download-") as tmp:
            before = guard.fingerprints()
            version = guard.installed()
            root = Path(tmp)
            stage = guard.stage(root)
            try:
                env = guard.stage_env(stage)
                env["MISE_OFFLINE"] = "0"
                env["PATH"] = str(stage / "candidate") + ":" + env["PATH"]
                # Same-version download exercises the installer; never promotes or changes the pin.
                guard.sandbox(stage, [stage / "candidate/mise", "self-update", "--yes",
                    "--no-plugins", "--force", version], network=True, env=env)
                guard.validate(stage, [guard.home / "etc"])
                self.assertEqual(guard.fingerprints(), before)
            finally:
                shutil.rmtree(stage)


if __name__ == "__main__":
    unittest.main()
