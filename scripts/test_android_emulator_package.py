"""Regression tests for deterministic Waffra emulator package discovery."""
import os
import pathlib
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).with_name("verify_android_emulator_package.sh")


class AndroidEmulatorPackageTests(unittest.TestCase):
    def run_check(self, mode, package="com.waffra.app"):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            adb = root / "adb"
            adb.write_text(
                "#!/bin/sh\n"
                "echo \"$*\" >> \"$ADB_CALLS\"\n"
                "if [ \"$*\" = 'shell pm path com.waffra.app' ]; then\n"
                "  n=$(cat \"$ADB_COUNT\" 2>/dev/null || echo 0)\n"
                "  n=$((n + 1))\n"
                "  echo \"$n\" > \"$ADB_COUNT\"\n"
                "  if [ \"$ADB_MODE\" = immediate ] || "
                "{ [ \"$ADB_MODE\" = delayed ] && [ \"$n\" -ge 3 ]; }; then\n"
                "    echo 'package:/data/app/com.waffra.app/base.apk'\n"
                "  fi\n"
                "fi\n"
            )
            adb.chmod(0o755)
            sleeper = root / "sleep"
            sleeper.write_text("#!/bin/sh\nexit 0\n")
            sleeper.chmod(0o755)
            env = dict(os.environ)
            env.update(
                PATH=str(root) + os.pathsep + env.get("PATH", ""),
                ADB_MODE=mode,
                ADB_COUNT=str(root / "count"),
                ADB_CALLS=str(root / "calls"),
            )
            result = subprocess.run(
                ["sh", str(SCRIPT), package], env=env,
                capture_output=True, text=True, timeout=15
            )
            calls = (root / "calls").read_text().splitlines() if (root / "calls").exists() else []
            return result, calls

    def test_registered_package_is_verified_without_package_enumeration(self):
        result, calls = self.run_check("immediate")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, ["shell pm path com.waffra.app"])
        self.assertIn("Verified installed Android package", result.stdout)

    def test_delayed_package_registration_is_retried(self):
        result, calls = self.run_check("delayed")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls.count("shell pm path com.waffra.app"), 3)

    def test_missing_package_fails_closed_after_bounded_retries(self):
        result, calls = self.run_check("missing")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls.count("shell pm path com.waffra.app"), 10)
        self.assertIn("not registered", result.stderr)

    def test_wrong_package_identity_is_rejected_without_adb(self):
        result, calls = self.run_check("immediate", "com.waffra.waffra")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls, [])
        self.assertIn("Unexpected Android package identity", result.stderr)


if __name__ == "__main__":
    unittest.main()
