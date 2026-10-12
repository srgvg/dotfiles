"""Exercise only update-tools' Codex block; never run a real installer."""
import json
import os
import pathlib
import subprocess
import unittest

SOURCE = pathlib.Path(__file__).resolve().parents[1] / "update-tools"
BLOCK = SOURCE.read_text().split('    log "codex"\n', 1)[1].split('    log "opencode"\n', 1)[0]


class CodexMaintenance(unittest.TestCase):
    def run_case(self, version, *, inspect_status=0, install_status=0):
        metadata = json.dumps({"dependencies": {"@openai/codex": {"version": version}}})
        shell = '''
set -u -o pipefail
FAILED_COMPONENTS=()
hash() { return 0; }
log() { :; }
err() { printf '%s\\n' "$*" >&2; }
codex() { printf 'codex-cli 99.0.0\\n'; }
npm() {
    if [[ "$1" == list ]]; then
        printf '%s\\n' "$TEST_METADATA"
        return "$TEST_INSPECT_STATUS"
    fi
    printf 'INSTALL %s\\n' "$*"
    return "$TEST_INSTALL_STATUS"
}
exercise() {
''' + BLOCK + '''
}
exercise
printf 'FAILURES %s\\n' "${FAILED_COMPONENTS[*]}"
'''
        env = dict(os.environ, TEST_METADATA=metadata,
                   TEST_INSPECT_STATUS=str(inspect_status),
                   TEST_INSTALL_STATUS=str(install_status))
        result = subprocess.run(["bash", "--noprofile", "--norc"], input=shell,
                                text=True, capture_output=True, env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout, result.stderr

    def test_old_npm_install_upgrades_despite_newer_codex_on_path(self):
        out, _ = self.run_case("0.153.4")
        self.assertIn("INSTALL install -g @openai/codex@0.162.1", out)
        self.assertIn("FAILURES \n", out)

    def test_current_and_newer_installs_are_preserved(self):
        for version in ("0.162.1", "0.162.2", "0.163.0", "0.1000.0", "1.0.0"):
            with self.subTest(version=version):
                out, _ = self.run_case(version)
                self.assertNotIn("INSTALL", out)
                self.assertIn("FAILURES \n", out)

    def test_unreadable_or_nonrelease_version_never_installs(self):
        for version, status in (("0.153.4", 1), (None, 0), ("garbage", 0),
                                ("0.163.0-alpha.1", 0)):
            with self.subTest(version=version, status=status):
                out, err = self.run_case(version, inspect_status=status)
                self.assertNotIn("INSTALL", out)
                self.assertIn("FAILURES codex", out)
                self.assertTrue(err)

    def test_failed_install_reaches_failure_summary(self):
        out, _ = self.run_case("0.153.4", install_status=1)
        self.assertIn("FAILURES codex", out)


if __name__ == "__main__":
    unittest.main()
