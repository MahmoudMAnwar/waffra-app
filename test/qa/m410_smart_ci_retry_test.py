"""M410: only transient failures may trigger bounded failed-job-only retries."""
import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/qa/m410_failed_job_retry.py"
spec = importlib.util.spec_from_file_location("m410_retry", SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

SHA = "a" * 40
RUN = {
    "name": module.WORKFLOW, "event": "pull_request",
    "conclusion": "failure", "run_attempt": 1,
    "head_sha": SHA, "head_branch": "fix/sample",
    "head_repository": {"full_name": "MahmoudMAnwar/waffra-app"},
}
EVENT = {"repository": {"full_name": "MahmoudMAnwar/waffra-app"},
         "workflow_run": RUN}
JOBS = [{"id": 12345, "name": module.JOB, "conclusion": "failure"},
        {"id": 12346, "name": "widget-ui-and-golden-candidates",
         "conclusion": "success"}]
LOG = ("✓ Built app-debug.apk\n"
       "registerService: (-32000) Service connection disposed\n"
       "adb: device offline\n")


class BoundedRetryTest(unittest.TestCase):
    def candidate(self, event=None, jobs=None, log=LOG, sha=SHA):
        return module.candidate(
            event if event is not None else EVENT,
            jobs if jobs is not None else JOBS,
            log, sha)

    def test_one_known_infrastructure_job_only(self):
        self.assertEqual(self.candidate()[0], 12345)

    def test_actual_widget_assertion_cannot_be_retried(self):
        selected, why = self.candidate(log=LOG + "\nExpected: true\nActual: false")
        self.assertIsNone(selected)
        self.assertIn("assertion", why)

    def test_non_infrastructure_failures_are_not_auto_retried(self):
        self.assertIsNone(self.candidate(log="Error: Flutter compile failed")[0])

    def test_old_run_not_retried_when_pr_head_moved(self):
        self.assertIsNone(self.candidate(sha="b" * 40)[0])

    def test_only_once_even_when_second_attempt_fails(self):
        event = {"repository": EVENT["repository"],
                 "workflow_run": dict(RUN, run_attempt=2)}
        self.assertIsNone(self.candidate(event=event)[0])

    def test_other_failed_jobs_cannot_be_hidden(self):
        failed = JOBS + [{"id": 89, "name": "unrelated",
                          "conclusion": "failure"}]
        self.assertIsNone(self.candidate(jobs=failed)[0])

    def test_forks_never_receive_write_permissions(self):
        run = dict(RUN, head_repository={"full_name": "attacker/repo"})
        event = {"repository": EVENT["repository"], "workflow_run": run}
        self.assertIsNone(self.candidate(event=event)[0])

    def test_full_sha_and_run_event_are_mandatory(self):
        event = {"repository": EVENT["repository"],
                 "workflow_run": dict(RUN, head_sha="bad", event="push")}
        self.assertIsNone(self.candidate(event=event)[0])

    def test_workflow_preserves_review_and_main_gates(self):
        text = (ROOT / ".github/workflows/m410-failed-android-retry.yml").read_text()
        self.assertIn("workflow_run:", text)
        self.assertIn("actions: write", text)
        self.assertIn("run_attempt == 1", text)
        self.assertIn("persist-credentials: false", text)
        self.assertNotIn("continue-on-error: true", text)
        release = (ROOT / ".github/workflows/android.yml").read_text()
        self.assertIn("needs: [verify-all-tests, verify-same-sha-checks]", release)


if __name__ == "__main__":
    unittest.main()
