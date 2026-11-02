"""M386 regression: emulator disk quota, NOT removal of Android UI tap QA."""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github/workflows/m274-production-ui-golden.yml"


class M274EmulatorDiskBudgetTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.workflow = WORKFLOW.read_text(encoding="utf-8")

    def test_real_android_engine_is_still_required(self):
        for required in (
            "android-emulator-ui-taps:",
            "reactivecircus/android-emulator-runner@v2",
            "bash .github/scripts/run-m274-android-tap-smoke.sh",
            "api-level: 35",
            "target: google_apis",
            "arch: x86_64",
            "profile: pixel_6",
        ):
            self.assertIn(required, self.workflow)

    def test_lower_emulator_userdata_budget_avoids_documented_7372_mb_requirement(self):
        from_anchor = self.workflow.split(
            "      - name: Run real Android-engine tap sequence on emulator", 1
        )[-1]
        self.assertIn("disk-size: 3072M", from_anchor)
        self.assertLess(3072, 5911, "Emulator partition must fit observed runner free space")
        self.assertIn("ram-size: 3072M", from_anchor)
        self.assertIn("heap-size: 512M", from_anchor)
        self.assertIn("emulator-boot-timeout: 600", from_anchor)

    def test_failure_not_hidden_by_skipping_or_continue_on_error(self):
        job = self.workflow.split("  android-emulator-ui-taps:", 1)[-1]
        self.assertNotIn("continue-on-error: true", job)
        self.assertNotIn("if: false", job)
        self.assertNotIn("exit 0", job)
        self.assertIn("Run real Android-engine tap sequence on emulator", job)


if __name__ == "__main__":
    unittest.main()
