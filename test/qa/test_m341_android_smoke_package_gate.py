"""M341/M342 — verify the EXACT Android smoke script executed on the emulator.

The YAML invokes a separate Bash script as one command to avoid the Android
emulator runner's per-line /bin/sh execution. Validating dead inline YAML text
would miss a removed package/launch check and block correctly refactored CI.
"""
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github/workflows/android-full-smoke.yml"
STARTUP_SCRIPT = ROOT / "scripts/qa/verify_android_release_startup.sh"
SCRIPT_RELATIVE = "scripts/qa/verify_android_release_startup.sh"


class AndroidStartupSmokeTest(unittest.TestCase):
    def test_workflow_executes_strict_startup_script_as_one_command(self):
        workflow = WORKFLOW.read_text(encoding="utf-8")
        self.assertRegex(
            workflow,
            r"(?m)^\s*script:\s*bash -euo pipefail "
            + re.escape(SCRIPT_RELATIVE) + r"\s*$",
        )
        self.assertRegex(
            workflow,
            r"(?m)^\s*run:\s*bash -n "
            + re.escape(SCRIPT_RELATIVE) + r"\s*$",
        )
        self.assertIn("Configure Firebase Google Sign-In", workflow)
        self.assertTrue(STARTUP_SCRIPT.is_file(), "Executed smoke script missing")
        syntax = subprocess.run(
            ["bash", "-n", str(STARTUP_SCRIPT)],
            capture_output=True, text=True, check=False,
        )
        self.assertEqual(0, syntax.returncode, syntax.stderr)

    def test_android_smoke_uses_exact_google_package_and_real_launch_proof(self):
        script = STARTUP_SCRIPT.read_text(encoding="utf-8")
        # Do not accept claims in comments as executable checks.
        commands = "\n".join(
            line for line in script.splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        )
        self.assertRegex(commands, r"(?m)^set -euo pipefail$")
        self.assertRegex(commands, r'(?m)^PACKAGE="com\.waffra\.app"$')
        self.assertIn('adb install -r "$APK"', commands)
        self.assertRegex(
            commands,
            r'(?s)if ! adb shell pm path "\$PACKAGE" '
            r'\| tr -d \'\\r\' \| grep -q \'\^package:\'; then\n'
            r'.*?\n\s*exit 1\nfi',
        )
        self.assertIn('adb shell monkey -p "$PACKAGE"', commands)
        self.assertIn('adb shell pidof "$PACKAGE"', commands)
        self.assertIn("adb logcat -c", commands)
        self.assertIn("FATAL EXCEPTION", commands)
        self.assertIn("Waffra startup failed:", commands)
        self.assertNotIn("adb shell pm list packages -3", commands)


if __name__ == "__main__":
    unittest.main()
