"""End-to-end shell regressions for the Android emulator smoke entrypoint."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
STARTUP = ROOT / "scripts/verify_android_emulator_startup.sh"
VERIFY = ROOT / "scripts/verify_android_emulator_package.sh"
WORKFLOW = ROOT / ".github/workflows/android-full-smoke.yml"


class AndroidEmulatorStartupTests(unittest.TestCase):
    def run_smoke(self, mode):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "scripts").mkdir()
            shutil.copyfile(VERIFY, root / "scripts/verify_android_emulator_package.sh")
            adb = root / "adb"
            adb.write_text(
                '#!/bin/sh\n'
                'echo "$*" >> "$ADB_CALLS"\n'
                'case "$*" in\n'
                '  "shell pm path com.waffra.app")\n'
                '    if [ "$ADB_MODE" != missing ]; then\n'
                '      echo "package:/data/app/com.waffra.app/base.apk"\n'
                '    fi;;\n'
                '  "shell pidof com.waffra.app")\n'
                '    if [ "$ADB_MODE" = dead ]; then exit 1; fi\n'
                '    echo 1234;;\n'
                '  "logcat -d -t 2000")\n'
                '    if [ "$ADB_MODE" = fatal ]; then echo "FATAL EXCEPTION: main"; fi;;\n'
                'esac\n'
            )
            adb.chmod(0o755)
            sleeper = root / "sleep"
            sleeper.write_text("#!/bin/sh\nexit 0\n")
            sleeper.chmod(0o755)
            env = dict(os.environ)
            env.update(PATH=str(root) + os.pathsep + env.get("PATH", ""),
                       ADB_CALLS=str(root / "adb-calls"), ADB_MODE=mode)
            result = subprocess.run(
                ["sh", str(STARTUP)], cwd=root, env=env,
                capture_output=True, text=True, timeout=20
            )
            calls = (root / "adb-calls").read_text().splitlines()
            return result, calls

    def test_workflow_uses_one_shell_process(self):
        workflow = WORKFLOW.read_text()
        self.assertIn("sh scripts/verify_android_emulator_startup.sh", workflow)
        self.assertNotIn('sh scripts/verify_android_emulator_package.sh "$PACKAGE"', workflow)

    def test_shell_is_posix_valid(self):
        result = subprocess.run(["sh", "-n", str(STARTUP)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_success_verifies_package_and_launches(self):
        result, calls = self.run_smoke("success")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("shell pm path com.waffra.app", calls)
        self.assertIn("shell monkey -p com.waffra.app -c android.intent.category.LAUNCHER 1", calls)
        self.assertIn("Release app launched", result.stdout)

    def test_unregistered_package_never_launches(self):
        result, calls = self.run_smoke("missing")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("shell monkey -p com.waffra.app -c android.intent.category.LAUNCHER 1", calls)
        self.assertIn("not registered", result.stderr)

    def test_process_exit_is_rejected(self):
        result, calls = self.run_smoke("dead")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Waffra process exited", result.stderr)

    def test_fatal_android_log_is_rejected(self):
        result, calls = self.run_smoke("fatal")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Release startup error detected", result.stderr)


if __name__ == "__main__":
    unittest.main()
