"""Offline regressions: fixture files only; browser, Git and disk operations mocked.

Run: python3 ~/bin/tests/test-script-safety.py
Fixtures live under TMPDIR (default ~/tmp) and are removed by unittest cleanup.
"""
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import tempfile
import time
import unittest
from datetime import datetime, timezone

BIN = Path(__file__).resolve().parents[1]


class Fixture(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(
            prefix="script-safety-", dir=os.environ.get("TMPDIR", Path.home() / "tmp"))
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.home = self.root / "home"
        self.mockbin = self.root / "mockbin"
        self.home.mkdir()
        self.mockbin.mkdir()
        (self.home / "bin").mkdir()
        colors = set(re.findall(r"\b(echo_[a-z_]+)\b", (BIN / "git-rmstalebr").read_text()))
        (self.home / "bin/common.bash").write_text(
            "set -euo pipefail\nifdebug3() { [[ ${DEBUG:-0} -ge 3 ]]; }\n"
            + "\n".join(f"{name}=''" for name in sorted(colors)) + "\n")
        self.log = self.root / "calls.jsonl"
        self.env = dict(os.environ, HOME=str(self.home), TMPDIR=str(self.root),
                        PATH=f"{self.mockbin}:/usr/bin:/bin", TZ="UTC", LC_ALL="C",
                        TEST_ROOT=str(self.root), TEST_LOG=str(self.log))
        self.env.pop("BASH_ENV", None)
        self.env.pop("DEBUG", None)

    def script(self, name, body, interpreter="/usr/bin/python3"):
        path = self.mockbin / name
        path.write_text(f"#!{interpreter}\n" + body)
        path.chmod(0o700)
        return path

    def run_script(self, name, *args, env=None):
        return subprocess.run(["/bin/bash", str(BIN / name), *map(str, args)],
                              cwd=self.root, env=env or self.env, input="",
                              text=True, capture_output=True, timeout=15)

    def calls(self):
        if not self.log.exists():
            return []
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def file(self, name, content="original", *, age=0):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        if age:
            stamp = time.time() - age * 86400
            os.utime(path, (stamp, stamp))
        return path


class BrowserPicker(Fixture):
    def setUp(self):
        super().setUp()
        self.capture = self.root / "browser.json"
        browser = self.script("browser", """import json, os, sys
from pathlib import Path
Path(os.environ['TEST_ROOT'], 'browser.json').write_text(json.dumps(sys.argv[1:]))
""")
        config = self.home / ".config/browser-picker"
        config.mkdir(parents=True)
        (config / "browsers.conf").write_text(f"Test | {shlex.quote(str(browser))} --profile 'my profile' %u\n")
        # Exclude the real wofi entirely, even if installed on the host.
        self.env["PATH"] = str(self.mockbin)

    def test_url_is_one_literal_argument_in_both_paths(self):
        urls = ["https://example.invalid/?a=1&b=2", "https://example.invalid/a b'\"c",
                "https://example.invalid/; printf EXECUTED", "https://example.invalid/$(printf EXECUTED)",
                "https://example.invalid/`printf EXECUTED`", "https://example.invalid/a\nb\\c", ""]
        for interactive in (False, True):
            if interactive:
                self.script("wofi", "import sys\nsys.stdin.read()\nprint('Test')\n")
            for url in urls:
                with self.subTest(interactive=interactive, url=url):
                    self.capture.unlink(missing_ok=True)
                    result = self.run_script("browser-picker", url)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout, "")
                    self.assertEqual(json.loads(self.capture.read_text()), ["--profile", "my profile", url])

    def test_cancel_and_info_row_do_not_launch(self):
        for output in ("", "── https://example.invalid ──"):
            self.script("wofi", f"import sys\nsys.stdin.read()\nprint({output!r})\n")
            result = self.run_script("browser-picker", "https://example.invalid")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(self.capture.exists())


class Rename(Fixture):
    STAMP = 1700000000

    def photo(self, name, content="original"):
        path = self.file(name, content)
        os.utime(path, (self.STAMP, self.STAMP))
        return path

    def timestamp_destination(self, source, action=1):
        ts = datetime.fromtimestamp(self.STAMP, timezone.utc).strftime("%Y%m%d%H%M%S")
        return source.with_name(f"{ts}-{source.name}" if action == 1 else f"{ts}{source.suffix}")

    def test_timestamp_duplicate_destination_preserves_entire_batch(self):
        first, second = self.photo("a.jpg", "a"), self.photo("b.jpg", "b")
        for args in (("2",), ("-c", "2"), ("02",)):
            with self.subTest(args=args):
                result = self.run_script("rename2timestamp", *args, first, second)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Duplicate destination", result.stderr)
                self.assertEqual(first.read_text(), "a")
                self.assertEqual(second.read_text(), "b")
                self.assertFalse(self.timestamp_destination(first, 2).exists())

    def test_existing_destination_and_dangling_symlink_preserve_batch(self):
        first, second = self.photo("first.jpg"), self.photo("second.jpg")
        dest = self.timestamp_destination(second)
        for symlink in (False, True):
            with self.subTest(symlink=symlink):
                if symlink:
                    dest.symlink_to(self.root / "missing")
                else:
                    dest.write_text("keep")
                result = self.run_script("rename2timestamp", "1", first, second)
                self.assertNotEqual(result.returncode, 0)
                self.assertTrue(first.exists())
                self.assertTrue(second.exists())
                self.assertFalse(self.timestamp_destination(first).exists())
                self.assertTrue(dest.is_symlink() if symlink else dest.read_text() == "keep")
                dest.unlink()

    def test_timestamp_quoted_names_copy_move_and_preview(self):
        for name in ("holiday photo.jpg", "glob[*]?.jpg", "-photo.jpg", "line\nbreak.jpg"):
            with self.subTest(name=name):
                source = self.photo(name)
                dest = self.timestamp_destination(source)
                preview = self.run_script("rename2timestamp", name)
                self.assertEqual(preview.returncode, 0, preview.stderr)
                self.assertTrue(source.exists())
                self.assertFalse(dest.exists())
                copied = self.run_script("rename2timestamp", "-c", "1", name)
                self.assertEqual(copied.returncode, 0, copied.stderr)
                self.assertTrue(source.exists())
                self.assertEqual(dest.read_text(), "original")
                dest.unlink()
                moved = self.run_script("rename2timestamp", "1", name)
                self.assertEqual(moved.returncode, 0, moved.stderr)
                self.assertFalse(source.exists())
                self.assertEqual(dest.read_text(), "original")

    def test_rename_spaces_collision_noop_and_preview(self):
        first = self.file("first file")
        source = self.file("a b", "source")
        dest = self.file("a_b", "keep")
        result = self.run_script("rename4space", "do", first, source)
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(first.exists())
        self.assertEqual(source.read_text(), "source")
        self.assertEqual(dest.read_text(), "keep")
        noop = self.run_script("rename4space", "do", dest)
        self.assertEqual(noop.returncode, 0, noop.stderr)
        preview = self.run_script("rename4space", first)
        self.assertEqual(preview.returncode, 0, preview.stderr)
        self.assertTrue(first.exists())
        dest.unlink()
        moved = self.run_script("rename4space", "do", first, source)
        self.assertEqual(moved.returncode, 0, moved.stderr)
        self.assertEqual(dest.read_text(), "source")
        self.assertTrue((self.root / "first_file").exists())

    def test_parent_aliases_are_duplicate_destinations(self):
        source = self.photo("photos/a.jpg")
        (self.root / "alias").symlink_to(source.parent, target_is_directory=True)
        result = self.run_script("rename2timestamp", "1", source, self.root / "alias/a.jpg")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Duplicate destination", result.stderr)
        self.assertTrue(source.exists())

    def test_root_parent_and_directory_trailing_slash(self):
        shell = f'''source {shlex.quote(str(BIN / 'lib/rename-safe.bash'))}
rename_path /example.txt
printf '%s' "$RENAME_PATH"
'''
        result = subprocess.run(["/bin/bash", "-c", shell], capture_output=True, text=True, check=True)
        self.assertEqual(result.stdout, "/example.txt")
        directory = self.root / "photos"
        directory.mkdir()
        os.utime(directory, (self.STAMP, self.STAMP))
        result = self.run_script("rename2timestamp", "01", str(directory) + "/")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("20231114221320-photos.photos", result.stdout)

    def test_timestamp_unchanged_name_and_rename_spaces_special_names(self):
        source = self.photo("20231114221320.jpg")
        for args in (("2",), ("-c", "2")):
            result = self.run_script("rename2timestamp", *args, source)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, "")
            self.assertEqual(source.read_text(), "original")
        for name in ("-leading space", "glob[*] space", "line\nbreak space"):
            source = self.file(name)
            result = self.run_script("rename4space", "do", name)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(source.exists())
            self.assertEqual((self.root / name.replace(" ", "_")).read_text(), "original")

    def test_destination_appearing_during_copy_or_move_is_not_overwritten(self):
        for operation in ("mv", "cp"):
            with self.subTest(operation=operation):
                source = self.photo(f"{operation}.jpg")
                dest = self.timestamp_destination(source)
                self.script(operation, f"""import os, sys
from pathlib import Path
Path(sys.argv[-1]).write_text('racer')
os.execv('/usr/bin/{operation}', ['{operation}', *sys.argv[1:]])
""")
                args = ("-c", "1") if operation == "cp" else ("1",)
                result = self.run_script("rename2timestamp", *args, source)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertRegex(result.stderr, "skipped|not replacing")
                self.assertEqual(source.read_text(), "original")
                self.assertEqual(dest.read_text(), "racer")


class Cleanup(Fixture):
    def setUp(self):
        super().setUp()
        self.target = self.root / "cleanup [test]"
        self.target.mkdir()
        self.script("sleep", "", interpreter="/bin/sh")

    def age(self, path):
        stamp = time.time() - 10 * 86400
        os.utime(path, (stamp, stamp), follow_symlinks=False)

    def test_recent_descendants_and_protected_trees_survive(self):
        old = self.file("cleanup [test]/old-parent/old", age=10)
        fresh = self.file("cleanup [test]/old-parent/fresh")
        protected = self.file("cleanup [test]/ssh-agent/nested/old", age=10)
        emptied = self.file("cleanup [test]/will-empty/old", age=10)
        empty = self.target / "empty"
        empty.mkdir()
        for path in (old.parent, protected.parent, protected.parent.parent, emptied.parent, empty):
            self.age(path)
        preview = self.run_script("clean-tmp.sh", "--path", self.target)
        self.assertEqual(preview.returncode, 0, preview.stderr)
        self.assertIn(str(old), preview.stdout)
        self.assertNotIn(str(fresh), preview.stdout)
        self.assertNotIn(str(protected), preview.stdout)
        self.assertTrue(old.exists())
        result = self.run_script("clean-tmp.sh", "--path", self.target, "--no-dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(old.exists())
        self.assertFalse(emptied.exists())
        self.assertFalse(empty.exists())
        self.assertTrue(emptied.parent.exists())
        self.assertTrue(fresh.exists())
        self.assertTrue(protected.exists())

    def test_symlink_target_is_not_followed(self):
        outside = self.file("outside/keep", age=10)
        link = self.target / "old-link"
        link.symlink_to(outside.parent, target_is_directory=True)
        self.age(link)
        result = self.run_script("clean-tmp.sh", "--path", self.target, "--no-dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(link.is_symlink())
        self.assertEqual(outside.read_text(), "original")

    def test_canonical_sensitive_targets_rejected(self):
        alias = self.root / "home-alias"
        alias.symlink_to("/home", target_is_directory=True)
        for target in ("/home/", "/home/../", "/bin/", alias):
            with self.subTest(target=target):
                result = self.run_script("clean-tmp.sh", "--path", target)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Refusing", result.stderr)

    def test_ownership_filter_and_all_override(self):
        old = self.file("cleanup [test]/old", age=10)
        # Claim a different current UID; the real file then fails the ownership filter.
        self.script("id", f"print({os.getuid() + 1})\n")
        result = self.run_script("clean-tmp.sh", "--path", self.target, "--no-dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(old.exists())
        result = self.run_script("clean-tmp.sh", "--path", self.target, "--no-dry-run", "--all")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(old.exists())

    def test_traversal_failure_is_nonzero_and_xdev_is_set(self):
        self.script("find", """import sys
assert '-xdev' in sys.argv
print('fixture traversal failure', file=sys.stderr)
sys.exit(9)
""")
        result = self.run_script("clean-tmp.sh", "--path", self.target)
        self.assertEqual(result.returncode, 9)
        self.assertIn("fixture traversal failure", result.stderr)

    def test_deletion_failure_is_reported(self):
        old = self.file("cleanup [test]/old", age=10)
        self.script("rm", "import sys\nsys.exit(2)\n")
        result = self.run_script("clean-tmp.sh", "--path", self.target, "--no-dry-run")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("Cleanup completed", result.stdout)
        self.assertTrue(old.exists())


GIT_MOCK = r'''import json, os, sys
from pathlib import Path
a = sys.argv[1:]
with open(os.environ['TEST_LOG'], 'a') as f:
    f.write(json.dumps(a) + '\n')
scenario = os.environ.get('SCENARIO', 'rebased')
if a == ['rev-parse', '--git-dir']: print('.git')
elif a == ['rev-parse', '--is-shallow-repository']: print('false')
elif a == ['rev-parse', '--show-toplevel']: print(os.environ['TEST_ROOT'])
elif a[0] == 'rev-parse': print('a' * 40)
elif a == ['symbolic-ref', '--short', 'HEAD']: print('main')
elif a[0] == 'symbolic-ref': print('refs/remotes/origin/main')
elif a[0] == 'config': print('origin')
elif a[0] in ('fetch', 'remote', 'show-ref'): pass
elif a[0] == 'for-each-ref':
    remote = a[-1] == 'refs/remotes/origin/'
    if '--merged=origin/main' in a:
        print('refs/remotes/origin/main' if remote else 'merged')
    elif '--no-merged=origin/main' in a:
        print('refs/remotes/origin/topic' if remote else 'feature')
    else: raise SystemExit('unexpected for-each-ref')
elif a[0] == 'cherry':
    if scenario == 'failure' and a[-1] == 'feature':
        print('fixture cherry failure', file=sys.stderr)
        sys.exit(128)
    if scenario == 'remote_failure' and a[-1] == 'origin/topic': sys.exit(128)
    if scenario == 'partial_failure' and a[-1] == 'feature':
        print('- ' + 'b' * 40)
        sys.exit(128)
    if scenario != 'empty':
        print(('+ ' if scenario == 'unique' else '- ') + 'b' * 40)
elif a == ['worktree', 'list', '--porcelain']:
    print(f"worktree {os.environ['TEST_ROOT']}\nHEAD {'a' * 40}\nbranch refs/heads/main\n")
elif a[0] == 'log': print('abcdef fixture')
elif a[0] in ('branch', 'push'): pass
else: raise SystemExit('unexpected git call: ' + repr(a))
'''


class BranchCleanup(Fixture):
    def setUp(self):
        super().setUp()
        self.script("git", GIT_MOCK)

    def deletions(self):
        return [a for a in self.calls() if a[0] in ("branch", "push") or a[:2] == ["worktree", "remove"]]

    def test_failed_workers_abort_all_deletions(self):
        for scenario in ("failure", "remote_failure", "partial_failure"):
            with self.subTest(scenario=scenario):
                self.log.unlink(missing_ok=True)
                result = self.run_script("git-rmstalebr", "-y", env=dict(self.env, SCENARIO=scenario))
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("git cherry exited 128", result.stderr)
                self.assertEqual(self.deletions(), [])
                self.assertEqual(sum(a[0] == "cherry" for a in self.calls()), 2)

    def test_unreadable_result_aborts_all_deletions(self):
        self.script("grep", """import os, sys
if sys.argv[-1].endswith('/l0'):
    sys.exit(2)
os.execv('/usr/bin/grep', ['grep', *sys.argv[1:]])
""")
        result = self.run_script("git-rmstalebr", "-y")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Cannot read comparison for feature", result.stderr)
        self.assertEqual(self.deletions(), [])

    def test_successful_classifications(self):
        for scenario in ("rebased", "unique", "empty"):
            with self.subTest(scenario=scenario):
                self.log.unlink(missing_ok=True)
                result = self.run_script("git-rmstalebr", "-y", env=dict(self.env, SCENARIO=scenario))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(["branch", "-d", "merged"], self.deletions())
                if scenario == "unique":
                    self.assertEqual(self.deletions(), [["branch", "-d", "merged"]])
                else:
                    self.assertIn(["branch", "-D", "feature"], self.deletions())
                    self.assertIn(["push", "origin", "--delete", "topic"], self.deletions())


WIPE_MOCK = r'''import json, os, sys
from pathlib import Path
name = Path(sys.argv[0]).name
a = sys.argv[1:]
root = Path(os.environ['TEST_ROOT'])
scenario = os.environ.get('SCENARIO', 'success')
with open(os.environ['TEST_LOG'], 'a') as f:
    f.write(json.dumps([name, *a]) + '\n')
if name == 'lsblk':
    if '--json' in a:
        if scenario == 'lsblk_failure': sys.exit(2)
        if scenario == 'lsblk_malformed': print('{}'); sys.exit()
        print(json.dumps({'blockdevices': [{'name': '/dev/sdz', 'maj:min': '8:240',
            'children': [{'name': '/dev/sdz1', 'maj:min': '8:241'}]}]}))
    elif '--output' in a and 'MAJ:MIN' in a: print('8:241')
elif name == 'findmnt':
    if '--target' in a: print('8:241'); sys.exit()
    if scenario == 'findmnt_failure': sys.exit(2)
    if scenario == 'findmnt_malformed': print('{}'); sys.exit()
    mounts = []
    for target in ['/media/test disk', '/media/test disk/nested\nmount']:
        if not (root / ('unmounted-' + str(len(target)))).exists() or scenario == 'residual_mount':
            mounts.append({'target': target, 'maj:min': '8:241'})
    mounts.append({'target': '/unrelated', 'maj:min': '8:1'})
    print(json.dumps({'filesystems': mounts}))
elif name == 'swapon':
    if scenario == 'swapon_failure': sys.exit(2)
    if not (root / 'swapoff').exists() or scenario == 'residual_swap': print('/dev/sdz1')
    print('/dev/unrelated')
elif name == 'swapoff':
    if scenario == 'swapoff_failure': sys.exit(2)
    (root / 'swapoff').touch()
elif name == 'umount':
    if scenario == 'umount_failure': sys.exit(2)
    (root / ('unmounted-' + str(len(a[-1])))).touch()
elif name == 'blockdev' and '--getsz' in a: print(65536)
elif name in ('sync', 'partprobe', 'udevadm', 'blockdev', 'wipefs', 'sgdisk', 'dd'): pass
else: raise SystemExit('unexpected command: ' + name)
'''


class WipeRemovable(Fixture):
    def setUp(self):
        super().setUp()
        for command in ("lsblk", "findmnt", "swapon", "swapoff", "umount", "sync",
                        "partprobe", "udevadm", "blockdev", "wipefs", "sgdisk", "dd"):
            self.script(command, WIPE_MOCK)
        # Only mocks, jq, and the explicitly invoked Bash can run. No real disk utility.
        (self.mockbin / "jq").symlink_to("/usr/bin/jq")
        self.env["PATH"] = str(self.mockbin)

    def wipe(self, scenario):
        shell = f'''source {shlex.quote(str(BIN / 'wipe-removable'))}
# Fixture device names are not real block devices; identity lookup is stubbed.
swap_device_id() {{
    if [[ "$1" == /dev/unrelated ]]; then printf '8:1\\n'; else printf '8:241\\n'; fi
}}
wipe_device sdz
'''
        return subprocess.run(["/bin/bash", "--noprofile", "--norc", "-c", shell],
                              input="YES\n", text=True, capture_output=True,
                              env=dict(self.env, SCENARIO=scenario), cwd=self.root, timeout=15)

    def test_failures_and_residual_use_never_reach_wipe(self):
        expected_errors = {
            "lsblk_failure": "Cannot enumerate /dev/sdz",
            "lsblk_malformed": "Invalid device inventory",
            "findmnt_failure": "Cannot enumerate mounts",
            "findmnt_malformed": "Invalid mount inventory",
            "swapon_failure": "Cannot enumerate active swap",
            "swapoff_failure": "Cannot disable swap",
            "umount_failure": "Cannot unmount",
            "residual_mount": "still has mounts or active swap",
            "residual_swap": "still has mounts or active swap",
        }
        for scenario, error in expected_errors.items():
            with self.subTest(scenario=scenario):
                self.log.unlink(missing_ok=True)
                for marker in self.root.glob("unmounted-*"):
                    marker.unlink()
                (self.root / "swapoff").unlink(missing_ok=True)
                result = self.wipe(scenario)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertIn(error, result.stderr)
                self.assertFalse(any(c[0] in ("wipefs", "sgdisk", "dd") for c in self.calls()))

    def test_success_orders_swap_unmount_recheck_then_wipe(self):
        result = self.wipe("success")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls()
        unmounts = [c for c in calls if c[0] == "umount"]
        self.assertEqual(unmounts, [["umount", "--", "/media/test disk/nested\nmount"],
                                   ["umount", "--", "/media/test disk"]])
        self.assertEqual([c for c in calls if c[0] == "swapoff"], [["swapoff", "--", "/dev/sdz1"]])
        self.assertLess(next(i for i, c in enumerate(calls) if c[0] == "swapoff"),
                        next(i for i, c in enumerate(calls) if c[0] == "umount"))
        recheck = max(i for i, c in enumerate(calls) if c[0] == "swapon")
        self.assertLess(recheck, next(i for i, c in enumerate(calls) if c[0] == "wipefs"))
        self.assertEqual(sum(c[0] == "dd" for c in calls), 2)

    def test_swap_file_identity_uses_containing_filesystem(self):
        swapfile = self.file("swap file\nwith newline")
        shell = f'''source {shlex.quote(str(BIN / 'wipe-removable'))}
swap_device_id "$1"
'''
        result = subprocess.run(["/bin/bash", "-c", shell, "test", str(swapfile)],
                                env=self.env, capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "8:241\n")
        self.assertEqual(self.calls(), [["findmnt", "--noheadings", "--raw", "--output",
                                        "MAJ:MIN", "--target", str(swapfile)]])


if __name__ == "__main__":
    unittest.main(verbosity=2)
