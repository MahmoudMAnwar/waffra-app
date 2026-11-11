"""M653: main APK must not wait for optional CI; mandatory finance never skips."""
from pathlib import Path
import unittest

from scripts.qa.m456_optional_retry_audit import classify_same_sha_checks

ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = ROOT / ".github" / "workflows"

def workflow(name):
    return (WORKFLOWS / name).read_text(encoding="utf-8")

REQUIRED = {
    "M174 Main SHA Post-Merge SQLCipher Regression",
    "M449 Release Notes Freshness Before Main Merge",
}
M201 = "M201 SQLCipher Routes, Migration and Receipt Acceptance (CI ONLY)"


class M653MainCIReleaseCriticalPathTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.main = workflow("android.yml")
        cls.m340 = workflow("m340-continuous-financial-quality.yml")
        cls.m174_compile = workflow("m174-main-arm64-compile.yml")
        cls.m174 = workflow("m174-main-sha-postmerge.yml")

    def test_exhaustive_main_verifier_includes_m340_source_guard_and_negative_tests(self):
        verify = self.main.split("  verify-all-tests:", 1)[1].split(
            "  verify-same-sha-checks:", 1)[0]
        for marker in (
            "m340_financial_quality_gate.py --json",
            "test_m34*_*.py",
            "flutter analyze --no-fatal-infos --no-fatal-warnings",
            "flutter test --reporter expanded",
            "unittest discover -s test/qa -p '*_test.py'",
            "unittest discover -s scripts -p 'test_smart_ci.py'",
        ):
            self.assertIn(marker, verify)
        self.assertNotIn("continue-on-error: true", verify)

    def test_exact_main_external_gates_required_and_optional_m201_fail_closed(self):
        audit = self.main.split("  verify-same-sha-checks:", 1)[1].split(
            "  build:", 1)[0]
        self.assertIn("'M174 Main SHA Post-Merge SQLCipher Regression'", audit)
        self.assertIn("'M449 Release Notes Freshness Before Main Merge'", audit)
        self.assertIn("'M201 SQLCipher Routes, Migration and Receipt Acceptance (CI ONLY)'", audit)
        self.assertIn("release_names = expected | {", audit)
        self.assertIn("checks = {name: item for name, item in checks.items()", audit)
        self.assertIn("if name in release_names", audit)
        self.assertIn("classify_same_sha_checks(checks, expected)", audit)
        self.assertIn("if failed:", audit)
        self.assertIn("if not missing and not pending:", audit)
        self.assertIn("BLOCKED: required same-SHA CI never finished", audit)
        self.assertIn("Non-release same-SHA check (not awaited):", audit)
        self.assertNotIn("'M340 Continuous Financial Quality Gate (Exact SHA, No Cutover)'", audit)

    def test_missing_failed_skipped_and_cancelled_required_gates_are_blockers(self):
        complete = lambda conclusion: {
            "status": "completed", "conclusion": conclusion,
            "html_url": "https://github.com/MahmoudMAnwar/waffra-app/actions",
        }
        good = {name: complete("success") for name in REQUIRED}
        self.assertEqual(classify_same_sha_checks(good, REQUIRED), ([], [], []))
        for name in REQUIRED:
            missing, pending, failed = classify_same_sha_checks(
                {k: v for k, v in good.items() if k != name}, REQUIRED)
            self.assertIn(name, missing)
            self.assertFalse(pending)
            self.assertFalse(failed)
            for bad in ("failure", "skipped", "cancelled", "timed_out"):
                results = dict(good)
                results[name] = complete(bad)
                missing, pending, failed = classify_same_sha_checks(results, REQUIRED)
                self.assertFalse(missing)
                self.assertFalse(pending)
                self.assertTrue(failed, msg=(name, bad))
        with_m201 = dict(good, **{M201: complete("failure")})
        self.assertTrue(classify_same_sha_checks(with_m201, REQUIRED)[2])
        running = dict(good)
        running[next(iter(REQUIRED))] = {"status": "in_progress", "conclusion": None}
        self.assertTrue(classify_same_sha_checks(running, REQUIRED)[1])

    def test_full_m340_pr_suite_retained_without_duplicate_main_push(self):
        self.assertIn("  pull_request:", self.m340)
        self.assertIn("  workflow_dispatch:", self.m340)
        self.assertNotIn("  push:", self.m340)
        for marker in (
            "source-contract:",
            "critical-finance-tests:",
            "full-app:",
            "combined-verdict:",
            "flutter test test/ --reporter expanded",
            "scripts/qa/m340_financial_quality_gate.py --json",
        ):
            self.assertIn(marker, self.m340)

    def test_unsigned_m174_diagnostic_is_manual_but_signed_main_apk_still_built(self):
        self.assertIn("  workflow_dispatch:", self.m174_compile)
        self.assertNotIn("  push:", self.m174_compile)
        self.assertNotIn("  pull_request:", self.m174_compile)
        self.assertIn("flutter build apk --release --no-pub --target-platform android-arm64",
                      self.m174_compile)
        self.assertIn("  push:", self.m174)
        self.assertIn("  pull_request:", self.m174)
        self.assertIn("needs: [verify-all-tests, verify-same-sha-checks]", self.main)
        self.assertIn("if: github.ref == 'refs/heads/main'", self.main)
        self.assertIn("matrix:", self.main)
        self.assertIn("artifact: [apk, aab]", self.main)
        self.assertIn("flutter build apk", self.main)
        self.assertIn("flutter build appbundle", self.main)
        self.assertIn("Verify final APK uses Firebase-registered Waffra release signing",
                      self.main)

    def test_historical_m410_noops_no_longer_trigger_automatically(self):
        retry = workflow("m410-failed-android-retry.yml")
        self.assertIn("  workflow_dispatch:", retry)
        self.assertNotIn("  workflow_run:", retry)
        self.assertNotIn("  push:", retry)

    def test_m647_prune_uses_real_discovery_and_still_fails_closed(self):
        prune = workflow("m647-main-history-prune.yml")
        self.assertIn(
            "python3 -m unittest discover -s test/qa -p 'm647_main_history_prune_test.py' -v",
            prune)
        self.assertNotIn("python3 -m unittest test/qa/m647_main_history_prune_test.py", prune)
        self.assertIn("actions: write", prune)
        self.assertIn("Snapshot, audit and prune old main failed/skipped/cancelled runs", prune)
        self.assertNotIn("continue-on-error: true", prune)


if __name__ == "__main__":
    unittest.main()
