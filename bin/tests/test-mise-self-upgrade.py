"""Offline failure/rollback tests. Real candidate validation is `mise-self-upgrade verify`."""
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

SOURCE = Path(__file__).resolve().parents[1] / "mise-self-upgrade"
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

    def test_bare_check_only_discovers(self):
        with (patch.object(mod.sys, "argv", ["mise-self-upgrade", "check"]),
              patch.object(mod, "Guard") as guard):
            self.assertEqual(mod.main(), 0)
            guard.return_value.discover.assert_called_once_with()
            guard.return_value.upgrade.assert_not_called()

    def test_bare_rollback_lists_without_selecting_a_record(self):
        with (patch.object(mod.sys, "argv", ["mise-self-upgrade", "rollback"]),
              patch.object(mod, "Guard") as guard):
            self.assertEqual(mod.main(), 0)
            guard.return_value.rollback.assert_called_once_with(None)

    def test_explicit_check_and_apply_still_require_validation(self):
        for action in ("check", "apply"):
            with (self.subTest(action=action),
                  patch.object(mod.sys, "argv", ["mise-self-upgrade", action, "2026.10.10"]),
                  patch.object(mod, "Guard") as guard):
                guard.return_value.home = Path("/home/test")
                self.assertEqual(mod.main(), 0)
                guard.return_value.discover.assert_not_called()
                guard.return_value.upgrade.assert_called_once_with(
                    action, "2026.10.10", [Path("/home/test/etc")])


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
            command = f"mise-self-upgrade rollback {self.root.name}"
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
        self.assertNotIn(f"mise-self-upgrade rollback {self.root.name}", output.getvalue())
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
            with patch.object(self.guard, "run") as run, self.assertRaises(mod.Refused):
                self.guard.maintain()
            run.assert_not_called()

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
        start = source.index("get_mise() {")
        block = source[start:source.index("\n}", start) + 2]
        block = block.replace('"$HOME/bin/mise-self-upgrade"', "fake_guard")
        p = subprocess.run(["/bin/bash", "--noprofile", "--norc", "-c",
                            "title() { :; }; fake_guard() { return 42; };\n" + block +
                            "\nif get_mise; then exit 99; else exit $?; fi"], capture_output=True, check=False)
        self.assertEqual(p.returncode, 42)

    def test_quick_mode_records_background_mise_failure(self):
        source = SOURCE.with_name("update-tools").read_text()
        start = source.index("update_quick() {")
        block = source[start:source.index("\n}", start) + 2]
        stubs = "\n".join(f"get_{name}() {{ return 0; }}" for name in
                           ("downloads", "flatpak", "helm", "krew", "misc", "uv_tools", "bash_completions"))
        p = subprocess.run(["/bin/bash", "--noprofile", "--norc", "-c",
                            "set -u; FAILED_COMPONENTS=();\n" + stubs +
                            "\nget_mise() { return 42; };\n" + block +
                            '\nupdate_quick; printf "%s\\n" "${FAILED_COMPONENTS[@]}"'],
                           capture_output=True, text=True, check=False)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(p.stdout, "mise\n")


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
