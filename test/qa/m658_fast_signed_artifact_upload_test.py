"""M658: signed main artifact uploads may be faster, never less safe."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github" / "workflows" / "android.yml"


class M658SignedUploadRegression(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = WORKFLOW.read_text(encoding="utf-8")
        cls.build = cls.source.split("\n  build:\n", 1)[1]

    def test_build_is_bounded_and_main_only(self):
        header = self.build.split("\n    steps:\n", 1)[0]
        self.assertIn("if: github.ref == 'refs/heads/main'", header)
        self.assertIn("needs: [verify-all-tests, verify-same-sha-checks]", header)
        self.assertIn("artifact: [apk, aab]", header)
        self.assertIn("fail-fast: false", header)
        self.assertRegex(header, r"(?m)^    timeout-minutes: 20$")
        self.assertIn("java-version: '21'", self.build)
        self.assertIn("Require JDK 21 before Android compilation", self.build)

    def test_two_unique_signed_artifacts_are_not_recompressed(self):
        self.assertEqual(self.build.count("uses: actions/upload-artifact@v4"), 2)
        entries = (
            ("Upload signed Google Play internal-testing AAB candidate",
             "Waffra-Android-API36-AAB-Internal-Test-Candidate",
             ("build/app/outputs/bundle/release/app-release.aab",
              "aab_candidate_sha256.txt"),
             "if: matrix.artifact == 'aab'"),
            ("Publish signed QA APK (FINAL step)",
             "Waffra-Android-ARM64-Release-${{ github.sha }}",
             ("build/Waffra.apk", "build/waffra-qa-build-receipt.txt",
              "build/Waffra-Release-Notes.txt"),
             "if: matrix.artifact == 'apk'"),
        )
        for name, artifact_name, paths, condition in entries:
            with self.subTest(name=name):
                part = self.build.split("      - name: " + name + "\n", 1)[1]
                step = part.split("\n      - name: ", 1)[0]
                self.assertIn(condition, step)
                self.assertIn("uses: actions/upload-artifact@v4", step)
                self.assertIn("name: " + artifact_name, step)
                self.assertIn("if-no-files-found: error", step)
                self.assertIn("compression-level: 0", step)
                self.assertIn("retention-days: 30", step)
                self.assertNotIn("continue-on-error:", step)
                for path in paths:
                    self.assertIn(path, step)
        self.assertEqual(self.build.count("compression-level: 0"), 2)
        self.assertEqual(self.build.count("retention-days: 30"), 2)

    def test_original_release_payload_and_identity_gate_stay_ordered(self):
        self.assertLess(
            self.build.index("Gate QA APK on embedded SHA and current branch head"),
            self.build.index("Publish signed QA APK (FINAL step)"))
        self.assertLess(
            self.build.index("Generate and validate Waffra Release Notes TXT"),
            self.build.index("Publish signed QA APK (FINAL step)"))
        self.assertLess(
            self.build.index("Verify signed AAB release certificate and compiled source identity"),
            self.build.index("Upload signed Google Play internal-testing AAB candidate"))

    def test_full_finance_and_signature_evidence_preserved(self):
        for marker in (
            "  verify-all-tests:",
            "  verify-same-sha-checks:",
            "M174 Main SHA Post-Merge SQLCipher Regression",
            "M449 Release Notes Freshness Before Main Merge",
            "Run every Flutter regression including future test files",
            "Build optimized ARM64 Release APK",
            "Build Android App Bundle candidate for Google Play internal testing",
            "Validate signed AAB archive (not a Play approval)",
            "Verify signed AAB release certificate and compiled source identity",
            "Verify final APK uses Firebase-registered Waffra release signing",
            "Gate QA APK on embedded SHA and current branch head",
            "Generate and validate Waffra Release Notes TXT",
        ):
            self.assertIn(marker, self.source)
        self.assertNotIn("continue-on-error: true", self.build)
        self.assertNotIn("|| true\n      - name: Publish signed", self.build)


if __name__ == "__main__":
    unittest.main()
