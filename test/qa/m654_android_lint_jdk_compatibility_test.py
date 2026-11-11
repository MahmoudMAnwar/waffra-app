"""M654 — protect Android Gradle/Lint from JDK17 JavaDocParser crash.

Issue #582: AGP bundled lint may invoke java.util.List.removeLast() that
does not exist on JDK 17; exact-PR M147 compile must actually check Lint.
These contracts ensure native build jobs use JDK21 without disabling lint.
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = ROOT / ".github" / "workflows"
BUILD_JOBS = (
    "m147-final-main-review-gate.yml",
    "android.yml",
    "m274-production-ui-golden.yml",
    "m174-main-arm64-compile.yml",
    "android-full-smoke.yml",
)


class M654AndroidLintJdkCompatibilityTest(unittest.TestCase):
    def test_all_active_flutter_android_build_paths_pin_java21(self):
        for filename in BUILD_JOBS:
            with self.subTest(workflow=filename):
                raw = (WORKFLOWS / filename).read_text(encoding="utf-8")
                self.assertIn("uses: actions/setup-java@v4", raw)
                self.assertIn("distribution: temurin", raw)
                self.assertIn("java-version: '21'", raw)
                self.assertNotIn("java-version: '17'", raw)
                self.assertIn("Require JDK 21 before Android compilation", raw)
                self.assertIn('java -version 2>&1 | grep -Eq \'version "21[.]\'', raw)
                self.assertLess(raw.index("java-version: '21'"),
                                raw.index("Require JDK 21 before Android compilation"))
                self.assertIn("flutter build", raw)

    def test_m147_job_compiles_real_arm64_with_lint_and_native_elf_guards(self):
        raw = (WORKFLOWS / "m147-final-main-review-gate.yml").read_text()
        job = raw.split("\n  android-arm64-compilation:\n", 1)[1]
        self.assertIn("Require JDK 21 before Android compilation", job)
        self.assertIn("flutter build apk --release --no-pub --target-platform android-arm64", job)
        self.assertIn("ARM64 compilation failed; never accept or publish a failed build", job)
        self.assertIn("Refuse APK missing native runtime libraries", job)
        self.assertNotIn("--no-lint", job)
        self.assertNotIn("-x lintVital", job)
        self.assertNotIn("continue-on-error: true", job)
        self.assertNotIn("lint { abortOnError = false", job)

    def test_main_signed_artifacts_and_pr_android_ui_still_verify_source(self):
        main = (WORKFLOWS / "android.yml").read_text()
        emulator = (WORKFLOWS / "m274-production-ui-golden.yml").read_text()
        self.assertIn("needs: [verify-all-tests, verify-same-sha-checks]", main)
        self.assertIn("Run every Flutter regression including future test files", main)
        self.assertIn("Build optimized ARM64 Release APK", main)
        self.assertIn("Build Android App Bundle candidate for Google Play internal testing", main)
        self.assertIn("Verify final APK uses Firebase-registered Waffra release signing", main)
        self.assertIn("M174 Main SHA Post-Merge SQLCipher Regression", main)
        self.assertIn("M449 Release Notes Freshness Before Main Merge", main)
        self.assertIn("android-emulator-ui-taps:", emulator)
        self.assertNotIn("continue-on-error: true", main)
        self.assertNotIn("continue-on-error: true", emulator)


if __name__ == "__main__":
    unittest.main()
