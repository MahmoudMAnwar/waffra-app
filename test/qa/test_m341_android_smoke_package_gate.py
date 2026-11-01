"""M341 — startup smoke must verify the exact Firebase app ID, not pm -3."""
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]

class AndroidStartupSmokeTest(unittest.TestCase):
    def test_android_smoke_uses_exact_google_package(self):
        workflow=(ROOT/'.github/workflows/android-full-smoke.yml').read_text(encoding='utf-8')
        self.assertIn('PACKAGE=com.waffra.app',workflow)
        self.assertIn('adb shell pm path "$PACKAGE"',workflow)
        self.assertIn('grep -q',workflow)
        self.assertIn('adb shell monkey -p "$PACKAGE"',workflow)
        self.assertIn('adb shell pidof "$PACKAGE"',workflow)
        self.assertNotIn('pm list packages -3',workflow.replace(
            '# "pm list packages -3"', '# avoided package enumeration'))
        self.assertIn('Configure Firebase Google Sign-In',workflow)

if __name__=="__main__":
    unittest.main()
