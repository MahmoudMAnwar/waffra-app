"""M659: PR #586 must run real, latest-head signed artifact source QA jobs."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github/workflows/m659-pr-signed-artifact-qa.yml"
ANDROID = ROOT / ".github/workflows/android.yml"


def job(source: str, job_name: str) -> str:
    marker = "  " + job_name + ":\n"
    jobs = source.split("\njobs:\n", 1)[1]
    assert jobs.count(marker) == 1, f"Expected one {job_name} job"
    tail = jobs.split(marker, 1)[1]
    import re
    next_job = re.search(r"(?m)^  [a-z][a-z0-9-]*:\s*$", tail)
    return tail[:next_job.start()] if next_job else tail


class M659PrArtifactJobsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = WORKFLOW.read_text(encoding="utf-8")
        cls.android = ANDROID.read_text(encoding="utf-8")

    def test_pr_updates_trigger_real_jobs_with_no_main_signed_pr_build(self):
        s = self.source
        self.assertIn("\non:\n  pull_request:\n", s)
        self.assertIn("branches: [main]", s)
        self.assertIn("types: [opened, synchronize, reopened, ready_for_review]", s)
        self.assertIn("'.github/workflows/android.yml'", s)
        self.assertIn("'test/qa/m658_fast_signed_artifact_upload_test.py'", s)
        self.assertIn("'test/qa/m659_pr_signed_artifact_jobs_test.py'", s)
        self.assertIn("'docs/release/WAFFRA_APPROVED_CHANGES.txt'", s)
        self.assertIn("cancel-in-progress: true", s)
        self.assertNotIn("\n  push:", s)
        self.assertIn("if: github.ref == 'refs/heads/main'", self.android)

    def test_both_required_jobs_check_out_exact_pr_sha_and_run(self):
        s = self.source
        for name in ("validate-m658-upload-contract", "validate-release-safety-contracts"):
            with self.subTest(job=name):
                body = job(s, name)
                self.assertIn("uses: actions/checkout@v4", body)
                self.assertIn("ref: ${{ github.event.pull_request.head.sha }}", body)
                self.assertIn("EXPECTED_SHA: ${{ github.event.pull_request.head.sha }}", body)
                self.assertIn('test "$(git rev-parse HEAD)" = "$EXPECTED_SHA"', body)
                self.assertIn("timeout-minutes:", body)
                self.assertNotIn("continue-on-error:", body)
                self.assertNotIn("if: false", body)
        self.assertEqual(s.count("ref: ${{ github.event.pull_request.head.sha }}"), 2)

    def test_focused_regressions_preserve_production_signing_and_release_gates(self):
        s = self.source
        upload = job(s, "validate-m658-upload-contract")
        release = job(s, "validate-release-safety-contracts")
        for testfile in ("m658_fast_signed_artifact_upload_test.py",
                         "m659_pr_signed_artifact_jobs_test.py"):
            self.assertIn("-p '" + testfile + "'", upload)
        for testfile in ("m381_main_fast_release_gate_test.py",
                         "m382_skip_free_workflow_routing_test.py",
                         "m383_parallel_signed_android_build_test.py",
                         "m449_release_notes_ancestry_test.py"):
            self.assertIn("-p '" + testfile + "'", release)
        self.assertIn("m385_approved_change_guard.py --base", release)
        self.assertIn("m449_release_notes_ancestry.py", release)
        self.assertIn("needs: [verify-all-tests, verify-same-sha-checks]", self.android)
        self.assertIn("M174 Main SHA Post-Merge SQLCipher Regression", self.android)
        self.assertIn("M449 Release Notes Freshness Before Main Merge", self.android)

    def test_terminal_certification_does_not_accept_skipped_or_failed_jobs(self):
        certify = job(self.source, "certify-m659")
        self.assertIn("if: ${{ always() }}", certify)
        self.assertIn(
            "needs: [validate-m658-upload-contract, validate-release-safety-contracts]",
            certify)
        self.assertIn("needs.validate-m658-upload-contract.result", certify)
        self.assertIn("needs.validate-release-safety-contracts.result", certify)
        self.assertIn('test "$UPLOAD_CONTRACT" = success', certify)
        self.assertIn('test "$RELEASE_CONTRACT" = success', certify)
        self.assertNotIn("continue-on-error:", certify)

    def test_pr_gate_never_builds_signs_or_publishes_android_artifacts(self):
        s = self.source
        for forbidden in ("flutter build", "flutter test", "gradlew",
                          "actions/upload-artifact", "actions/download-artifact",
                          "apksigner", "continue-on-error: true",
                          "|| true", "secrets."):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, s)
        self.assertEqual(s.count("uses: actions/checkout@v4"), 2)


if __name__ == "__main__":
    unittest.main()
