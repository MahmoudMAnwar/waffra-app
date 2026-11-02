"""M381: main APK speed improvements must never bypass finance release gates."""
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
ANDROID = ROOT / ".github/workflows/android.yml"
M340 = ROOT / ".github/workflows/m340-continuous-financial-quality.yml"
M174 = ROOT / ".github/workflows/m174-main-sha-postmerge.yml"


def job_scope(contents: str, name: str) -> str:
    marker = "  " + name + ":\n"
    start = contents.index(marker)
    match = re.search(r"(?m)^  [a-z][a-z0-9-]*:\s*$", contents[start + len(marker):])
    if match is None:
        return contents[start:]
    return contents[start:start + len(marker) + match.start()]


def step_section(contents: str, label: str) -> str:
    start = contents.index("      - name: " + label + "\n")
    next_step = contents.find("      - name:", start + 1)
    return contents[start:next_step if next_step != -1 else None]


class MainReleaseSpeedWithoutBypassTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.workflow = ANDROID.read_text(encoding="utf-8")
        cls.full = job_scope(cls.workflow, "verify-all-tests")
        cls.audit = job_scope(cls.workflow, "verify-same-sha-checks")
        cls.build = job_scope(cls.workflow, "build")

    def test_full_suite_still_mandatory_and_exhaustive(self):
        self.assertIn("flutter analyze --no-fatal-infos --no-fatal-warnings", self.full)
        self.assertIn("flutter test --reporter expanded", self.full)
        self.assertIn("unittest discover -s test/qa -p '*_test.py'", self.full)
        self.assertIn("unittest discover -s scripts -p 'test_smart_ci.py'", self.full)
        self.assertNotIn("if: github.ref != 'refs/heads/main'", self.full)

    def test_audit_runs_in_parallel_but_release_waits_for_both(self):
        self.assertNotIn("needs: verify-all-tests", self.audit)
        self.assertIn("needs: [verify-all-tests, verify-same-sha-checks]", self.build)
        self.assertIn("if failed:", self.audit)
        self.assertIn("if not missing and not pending:", self.audit)
        self.assertIn("raise SystemExit('BLOCKED: required same-SHA CI never finished')", self.audit)

    def test_nonempty_main_expected_checks_exist_and_run_on_main_push(self):
        for expected, file in [
            ("M340 Continuous Financial Quality Gate (Exact SHA, No Cutover)", M340),
            ("M174 Main SHA Post-Merge SQLCipher Regression", M174),
        ]:
            self.assertIn(expected, self.audit)
            contents = file.read_text(encoding="utf-8")
            self.assertIn("  push:", contents)
            self.assertIn("main", contents)
        self.assertIn("if branch == 'main'", self.audit)

    def test_main_build_does_not_duplicate_full_test_job(self):
        for step in [
            "Flutter static analysis",
            "Verify Smart CI safety policies",
            "Restore verified passing Flutter test fingerprints",
            "Run Smart Incremental Flutter tests",
            "Save verified green test fingerprints",
        ]:
            section = step_section(self.build, step)
            self.assertIn("if: github.ref != 'refs/heads/main'", section,
                msg=f"Main must not rerun already verified stage: {step}")
        self.assertIn("run: python3 scripts/smart_ci.py", self.build,
            "Historical QA branches retain their conservative incremental gate")

    def test_signing_play_bundle_and_identity_still_mandatory(self):
        for evidence in [
            "Configure and validate Waffra release signing",
            "Verify final APK uses Firebase-registered Waffra release signing",
            "Build optimized ARM64 Release APK",
            "Build Android App Bundle candidate for Google Play internal testing",
            "Validate signed AAB archive (not a Play approval)",
            "Gate QA APK on embedded SHA and current branch head",
            "Generate and validate Waffra Release Notes TXT",
            "Publish signed QA APK (FINAL step)",
        ]:
            self.assertIn(evidence, self.build)
        self.assertIn("flutter build appbundle", self.build)
        self.assertIn("flutter build apk", self.build)


if __name__ == "__main__":
    unittest.main()
