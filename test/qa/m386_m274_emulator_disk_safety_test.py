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
        self.assertIn("ram-size: 2048M", from_anchor)
        self.assertIn("heap-size: 256M", from_anchor)
        self.assertIn("emulator-boot-timeout: 600", from_anchor)

    def test_android_gradle_ndk_compilation_finishes_before_emulator_launch(self):
        job = self.workflow.split("  android-emulator-ui-taps:", 1)[-1]
        build = "flutter build apk --debug --no-pub --target integration_test/m274_ui_tap_smoke_android_test.dart"
        self.assertIn(build, job)
        self.assertIn("test -s build/app/outputs/flutter-apk/app-debug.apk", job)
        self.assertLess(job.index(build),
                        job.index("reactivecircus/android-emulator-runner@v2"))
        self.assertIn("df -h .", job)
        self.assertIn("free -h", job)

    def test_failure_not_hidden_by_skipping_or_continue_on_error(self):
        job = self.workflow.split("  android-emulator-ui-taps:", 1)[-1]
        self.assertNotIn("continue-on-error: true", job)
        self.assertNotIn("if: false", job)
        self.assertNotIn("exit 0", job)
        self.assertIn("Run real Android-engine tap sequence on emulator", job)


if __name__ == "__main__":
    unittest.main()
