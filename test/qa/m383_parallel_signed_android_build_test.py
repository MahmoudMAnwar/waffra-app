"""M383: parallel APK/AAB release must retain exact-source safety guarantees."""
from pathlib import Path
import unittest


WORKFLOW = (Path(__file__).resolve().parents[2]
            / ".github" / "workflows" / "android.yml")
APK_STEPS = (
    "Build optimized ARM64 Release APK",
    "Measure release APK size",
    "Verify final APK uses Firebase-registered Waffra release signing",
    "Gate QA APK on embedded SHA and current branch head",
    "Generate exact-commit APK checklist and SHA-256 receipt",
    "Generate and validate Waffra Release Notes TXT",
    "Stage verified Waffra.apk for download",
    "Publish signed QA APK (FINAL step)",
)
AAB_STEPS = (
    "Enforce Google Play Android 16 target SDK 36 for candidate AAB",
    "Build Android App Bundle candidate for Google Play internal testing",
    "Validate signed AAB archive (not a Play approval)",
    "Verify signed AAB release certificate and compiled source identity",
    "Upload signed Google Play internal-testing AAB candidate",
)


def section(workflow: str, step: str) -> str:
    tag = "      - name: " + step + "\n"
    if workflow.count(tag) != 1:
        raise AssertionError("Expected one step named: " + step)
    tail = workflow.split(tag, 1)[1]
    end = tail.find("      - name:")
    return tail if end < 0 else tail[:end]


class ParallelSignedAndroidBuildTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = WORKFLOW.read_text(encoding="utf-8")
        cls.build = cls.source.split("\n  build:\n", 1)[1]

    def test_exact_sha_full_release_gates_are_prerequisite_of_both_artifacts(self):
        s = self.source
        self.assertIn("  verify-all-tests:", s)
        self.assertIn("flutter analyze --no-fatal-infos --no-fatal-warnings", s)
        self.assertIn("Run every Flutter regression including future test files", s)
        self.assertIn("unittest discover -s test/qa -p '*_test.py'", s)
        self.assertIn("  verify-same-sha-checks:", s)
        self.assertIn("M340 Continuous Financial Quality Gate", s)
        self.assertIn("M174 Main SHA Post-Merge SQLCipher Regression", s)
        self.assertIn("needs: [verify-all-tests, verify-same-sha-checks]", self.build)
        self.assertIn("fail-fast: false", self.build)
        self.assertIn("artifact: [apk, aab]", self.build)
        self.assertIn("runs-on: ubuntu-latest", self.build)

    def test_apk_only_steps_do_not_wait_for_aab(self):
        for step in APK_STEPS:
            self.assertIn("if: matrix.artifact == 'apk'", section(self.build, step),
                          msg=f"APK step misrouted: {step}")
        self.assertIn("flutter build apk --no-pub --release", self.build)
        self.assertIn("Waffra-Android-ARM64-Release-${{ github.sha }}", self.build)
        self.assertIn("build/Waffra-Release-Notes.txt", self.build)
        self.assertIn("APK missing compiled source identity", self.build)

    def test_play_bundle_steps_are_independent_and_certified(self):
        for step in AAB_STEPS:
            self.assertIn("if: matrix.artifact == 'aab'", section(self.build, step),
                          msg=f"AAB step misrouted: {step}")
        self.assertIn("flutter build appbundle --no-pub --release", self.build)
        self.assertIn("targetSdk = 36", self.build)
        self.assertIn("compileSdk = 36", self.build)
        self.assertIn("jarsigner -verify", self.build)
        self.assertIn("keytool', '-printcert', '-jarfile'", self.build)
        self.assertIn("AAB embedded identity differs from exact tested SHA", self.build)
        self.assertIn("AAB signature certificate mismatch", self.build)
        self.assertIn("BLOCKED stale AAB", self.build)
        self.assertIn("Waffra-Android-API36-AAB-Internal-Test-Candidate", self.build)
        self.assertIn("aab_candidate_sha256.txt", self.build)
        self.assertIn("WAFFRA_AAB_BUILD_SECONDS=", self.build)

    def test_parallel_jobs_cannot_overwrite_each_others_caches(self):
        self.assertIn("waffra-gradle-tasks-v1-", self.build)
        self.assertIn("github.run_id }}-${{ matrix.artifact }}", self.build)
        self.assertEqual(
            self.build.count("github.run_attempt }}-${{ matrix.artifact }}"), 4)
        self.assertIn("actions/cache/restore@v4", self.build)
        self.assertIn("actions/cache/save@v4", self.build)
        self.assertIn("gradle/actions/setup-gradle@v4", self.build)

    def test_apk_and_aab_keep_same_input_configuration(self):
        self.assertIn("Stamp exact source revision into Android APK assets", self.build)
        self.assertIn("SOURCE_SHA: ${{ github.sha }}", self.build)
        self.assertIn("SOURCE_RUN: ${{ github.run_id }}", self.build)
        self.assertIn("Configure Firebase Google Sign-In", self.build)
        self.assertIn("Force Firebase Crashlytics OFF before native app startup", self.build)
        self.assertIn("Configure and validate Waffra release signing", self.build)
        self.assertIn("Generate Waffra app icon", self.build)
        self.assertIn("WAFFRA_RELEASE_STORE_PASSWORD", self.build)

    def test_production_cutover_is_not_proclaimed(self):
        self.assertIn("NOT Google Play release", self.build)
        self.assertIn("SQLCipher production cutover is NOT certified", self.build)
        self.assertIn("Do NOT upload to a Production Play track", self.build)


if __name__ == "__main__":
    unittest.main()
