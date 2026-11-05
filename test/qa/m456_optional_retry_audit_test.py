"""M456 regression: the APK gate never treats a no-op retry as failure."""
import unittest
from pathlib import Path

from scripts.qa.m456_optional_retry_audit import classify_same_sha_checks

M410 = "M410 Bounded Failed Android UI Job Retry"
REQUIRED = "M340 Continuous Financial Quality Gate (Exact SHA, No Cutover)"
REQUIRED_2 = "M174 Main SHA Post-Merge SQLCipher Regression"

def run(conclusion="success", status="completed"):
    return {"status": status, "conclusion": conclusion, "html_url": "https://github.com/example/test"}

class M456ApkSkipGateTests(unittest.TestCase):
    def checks(self, optional="skipped"):
        return {REQUIRED: run(), REQUIRED_2: run(), M410: run(optional)}

    def test_healthy_main_and_no_op_retry_allow_apk(self):
        self.assertEqual(
            classify_same_sha_checks(self.checks(), {REQUIRED, REQUIRED_2}),
            ([], [], []),
        )

    def test_actual_m410_failure_still_blocks_apk(self):
        missing, pending, failed = classify_same_sha_checks(
            self.checks("failure"), {REQUIRED, REQUIRED_2},
        )
        self.assertEqual((missing, pending), ([], []))
        self.assertEqual(failed[0][:2], (M410, "failure"))

    def test_m410_cancellation_or_timeout_still_blocks(self):
        for conclusion in ("cancelled", "timed_out", "action_required", None):
            with self.subTest(conclusion=conclusion):
                self.assertTrue(classify_same_sha_checks(
                    self.checks(conclusion), {REQUIRED, REQUIRED_2},
                )[2])

    def test_an_unrelated_skipped_workflow_is_not_hidden(self):
        checks = self.checks()
        checks["Waffra Real Security Test"] = run("skipped")
        self.assertEqual(
            classify_same_sha_checks(checks, {REQUIRED, REQUIRED_2})[2][0][0],
            "Waffra Real Security Test",
        )

    def test_required_skipped_workflow_blocks_even_if_name_is_m410(self):
        self.assertTrue(classify_same_sha_checks(
            self.checks(), {REQUIRED, REQUIRED_2, M410},
        )[2])

    def test_missing_required_workflow_blocks(self):
        self.assertEqual(classify_same_sha_checks(
            {REQUIRED: run(), M410: run("skipped")}, {REQUIRED, REQUIRED_2},
        )[0], [REQUIRED_2])

    def test_pending_required_or_optional_workflow_remains_blocked(self):
        for name in (REQUIRED, M410):
            with self.subTest(name=name):
                checks = self.checks()
                checks[name] = run(None, status="in_progress")
                self.assertIn(name, classify_same_sha_checks(
                    checks, {REQUIRED, REQUIRED_2})[1])

    def test_real_financial_failure_blocks(self):
        checks = self.checks()
        checks[REQUIRED] = run("failure")
        self.assertEqual(classify_same_sha_checks(
            checks, {REQUIRED, REQUIRED_2})[2][0][0], REQUIRED)

    def test_actual_apk_workflow_imports_the_gate(self):
        workflow = Path(".github/workflows/android.yml").read_text()
        self.assertIn(
            "from scripts.qa.m456_optional_retry_audit import classify_same_sha_checks",
            workflow,
        )
        self.assertIn(
            "missing, pending, failed = classify_same_sha_checks(checks, expected)",
            workflow,
        )
        self.assertIn(
            "if failed:\n                  for item in failed:",
            workflow,
        )

if __name__ == "__main__":
    unittest.main()
