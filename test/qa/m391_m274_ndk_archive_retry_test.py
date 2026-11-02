"""M391: a corrupted Android NDK download cannot silently disable real UI QA."""
from pathlib import Path
import unittest

WORKFLOW = (Path(__file__).resolve().parents[2]
            / ".github/workflows/m274-production-ui-golden.yml")


class AndroidNdkArchiveRetryTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.yaml = WORKFLOW.read_text(encoding="utf-8")

    def test_pinned_version_is_verified_and_retries_are_bounded(self):
        job = self.yaml.split("  android-emulator-ui-taps:", 1)[1]
        self.assertIn('version="28.2.13676358"', job)
        self.assertIn('for attempt in 1 2 3; do', job)
        self.assertIn('test -f "$sdk/ndk/$version/source.properties"', job)
        self.assertIn("grep -q 'Pkg.Revision = 28.2.13676358'", job)
        self.assertIn('exit 1', job)

    def test_ndk_preflight_happens_before_gradle_and_emulator(self):
        job = self.yaml.split("  android-emulator-ui-taps:", 1)[1]
        install = job.index("Install pinned Android NDK with bounded archive retries")
        build = job.index("Precompile Android UI integration APK before emulator launch")
        emulator = job.index("reactivecircus/android-emulator-runner@v2")
        self.assertLess(install, build)
        self.assertLess(build, emulator)
        self.assertIn("bash .github/scripts/run-m274-android-tap-smoke.sh", job)

    def test_ndk_failure_is_not_converted_to_a_pass_or_skipped(self):
        job = self.yaml.split("  android-emulator-ui-taps:", 1)[1]
        self.assertNotIn("continue-on-error: true", job)
        self.assertNotIn("if: false", job)
        self.assertIn("::error::Pinned Android NDK archive unavailable or corrupt", job)


    def test_prebuilt_android_drive_keeps_real_taps_and_failure_reporting(self):
        job = self.yaml.split("  android-emulator-ui-taps:", 1)[1]
        script = (WORKFLOW.parent / "scripts/run-m274-android-tap-smoke.sh").read_text(
            encoding="utf-8")
        self.assertIn("Prepare integration driver for prebuilt debug APK", job)
        self.assertIn("integrationDriver()", job)
        self.assertIn("flutter build apk --debug --no-pub --target integration_test/", job)
        self.assertIn("./android/gradlew --stop", job)
        self.assertIn("flutter drive --driver=test_driver/integration_test.dart", script)
        self.assertIn("--use-application-binary=build/app/outputs/flutter-apk/app-debug.apk", script)
        self.assertIn("integration_test/m274_ui_tap_smoke_android_test.dart", script)
        self.assertIn("M274_FAILURE_DIAGNOSTICS_BEGIN", script)
        self.assertIn("exit \"$result\"", script)
        self.assertNotIn("continue-on-error: true", job)
        self.assertNotIn('flutter test "$test_file"', script)


if __name__ == "__main__":
    unittest.main()
