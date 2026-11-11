"""M646: stop automatic skipped runs without reducing real Android gates."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
RETRY = ROOT / ".github/workflows/m410-failed-android-retry.yml"
ANDROID = ROOT / ".github/workflows/android.yml"
SCRIPT = ROOT / "scripts/qa/m410_failed_job_retry.py"
M267 = ROOT / ".github/workflows/m267-android-exact-apk-identity.yml"
M274 = ROOT / ".github/workflows/m274-production-ui-golden.yml"


class MainCiQuietContractTests(unittest.TestCase):
    def test_m410_manual_only_with_trusted_main_checkout(self):
        source = RETRY.read_text(encoding="utf-8")
        self.assertIn("workflow_dispatch:", source)
        self.assertIn("failed_m274_run_id:", source)
        self.assertIn("required: true", source)
        self.assertNotIn("workflow_run:", source)
        self.assertIn("actions: write", source)
        self.assertIn("persist-credentials: false", source)
        self.assertIn("ref: ${{ github.event.repository.default_branch }}", source)
        self.assertIn("SOURCE_M274_RUN_ID: ${{ inputs.failed_m274_run_id }}", source)

    def test_only_one_infrastructure_failure_and_no_arbitrary_reruns(self):
        source = SCRIPT.read_text(encoding="utf-8")
        for guard in (
            'GITHUB_EVENT_NAME") != "workflow_dispatch"',
            "SOURCE_M274_RUN_ID",
            'run.get("name")',
            'run.get("event") != "pull_request"',
            'run.get("run_attempt") != 1',
            'current_sha != run.get("head_sha")',
            'run.get("head_repository")',
            "not exactly one known failing Android UI job",
            "if ASSERTIONS.search(log):",
            "if not any(marker in log for marker in INFRA):",
            "actions/jobs/{selected}/rerun",
        ):
            self.assertIn(guard, source)
        self.assertNotIn("rerun-failed-jobs", source)

    def test_signed_apk_main_push_only_and_manual_branch_blocked(self):
        source = ANDROID.read_text(encoding="utf-8")
        trigger = source.split("on:\n", 1)[1].split("  workflow_dispatch:", 1)[0]
        self.assertIn("  push:\n    branches:\n      - main\n", "on:\n" + trigger)
        self.assertEqual(trigger.count("      - "), 1)
        build = source.split("  build:\n", 1)[1]
        self.assertIn("if: github.ref == 'refs/heads/main'", build[:400])
        self.assertIn("needs: [verify-all-tests, verify-same-sha-checks]", build)
        self.assertIn("flutter build apk", build)
        self.assertIn("flutter build appbundle", build)

    def test_real_android_and_two_phone_identity_not_removed(self):
        android = M274.read_text(encoding="utf-8")
        two_phone = M267.read_text(encoding="utf-8")
        self.assertIn("android-emulator-ui-taps:", android)
        self.assertIn("m274-required-android-certification:", android)
        self.assertIn("signed-apk-contract-negative-tests:", two_phone)
        self.assertIn("m267_signed_two_phone_apk_probe_test.py", two_phone)


if __name__ == "__main__":
    unittest.main()
