"""M453 regression: supersession never cancels main or unrelated PR jobs."""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "docs/qa/approved_change_scope.json"


class M453QueueSafetyTests(unittest.TestCase):
    def test_exact_pr_concurrency_for_every_modified_workflow(self):
        # Immutable M453 baseline: every PR must preserve these safeguards,
        # even when its own approved-change manifest describes unrelated work.
        paths = [
            ".github/workflows/finance-full-regression.yml",
            ".github/workflows/firestore-security-rules.yml",
            ".github/workflows/legacy-write-smoke.yml",
            ".github/workflows/m100-independent-runtime-gate.yml",
            ".github/workflows/m101-independent-runtime-gate.yml",
            ".github/workflows/m102-independent-runtime-gate.yml",
            ".github/workflows/m103-same-sha-release-certification.yml",
            ".github/workflows/m106-play-privacy-preflight.yml",
            ".github/workflows/m107-account-deletion-crash-privacy.yml",
            ".github/workflows/m108-home-widget-one-finance-commit.yml",
            ".github/workflows/m109-verified-finance-authority.yml",
            ".github/workflows/m110-home-writer-source-authority.yml",
            ".github/workflows/m111-finance-negative-acceptance.yml",
            ".github/workflows/m112-source-witness-acceptance.yml",
            ".github/workflows/m113-recovery-rollback-regression.yml",
            ".github/workflows/m114-sqlcipher-projected-editor.yml",
            ".github/workflows/m115-encrypted-receipt-authority.yml",
            ".github/workflows/m116-encrypted-receipt-replacement.yml",
            ".github/workflows/m117-receipt-retention-contract.yml",
            ".github/workflows/m118-encrypted-receipt-recycle.yml",
            ".github/workflows/m119-verified-receipt-screen-gateway.yml",
            ".github/workflows/m120-android-receipt-cold-reopen.yml",
            ".github/workflows/m121-atomic-receipt-screen-witness.yml",
            ".github/workflows/m122-receipt-expiry-clock-guard.yml",
            ".github/workflows/m123-production-cutover-release-gate.yml",
            ".github/workflows/m124-main-integration-audit.yml",
            ".github/workflows/m157-freeze-confirmed-merchant-category-acceptance.yml",
            ".github/workflows/m158-widget-sms-title-privacy.yml",
            ".github/workflows/m160-main-reconciliation.yml",
            ".github/workflows/m164-exact-ancestry-review.yml",
            ".github/workflows/m165-sqlcipher-no-cutover.yml",
            ".github/workflows/m166-android-qa-plan-lint.yml",
            ".github/workflows/m167-fresh-finance-backup-qa.yml",
            ".github/workflows/m168-firebase-owner-deletion-qa.yml",
            ".github/workflows/m169-bilingual-play-data-safety-qa.yml",
            ".github/workflows/m170-crashlytics-privacy-qa.yml",
            ".github/workflows/m171-android-supply-chain-review.yml",
            ".github/workflows/m172-rtl-accessibility-performance-qa.yml",
            ".github/workflows/m173-production-cutover-evidence-qa.yml",
            ".github/workflows/m174-main-sha-postmerge.yml",
            ".github/workflows/m317-ondevice-ai-brain.yml",
            ".github/workflows/m368-sqlcipher-stage-ci.yml",
            ".github/workflows/m369-sqlcipher-stage-ci.yml",
            ".github/workflows/m370-sqlcipher-stage-ci.yml",
            ".github/workflows/m371-goal-wallet-budget-android-regression.yml",
            ".github/workflows/m417-auto-bank-sms.yml",
            ".github/workflows/m422-phone-only-auth-ui.yml",
            ".github/workflows/m429-integration-smoke.yml",
            ".github/workflows/m440-account-ledger-and-backup-ci.yml",
            ".github/workflows/m80-parallel-independent-acceptance.yml",
            ".github/workflows/m89-integrated-m79-m88-acceptance.yml",
            ".github/workflows/m96-runtime-finance-cloud-integration.yml",
            ".github/workflows/m97-parallel-crash-and-ui-freeze.yml",
            ".github/workflows/m98-encrypted-recovery-inventory.yml",
            ".github/workflows/m99-manifest-last-cloud-sync.yml",
            ".github/workflows/storage-android-integration.yml",
            ".github/workflows/storage-preflight.yml",
            ".github/workflows/unified-finance-cloud-release-evidence.yml",
        ]
        self.assertEqual(len(paths), 58)
        for path in paths:
            with self.subTest(workflow=path):
                raw = (ROOT / path).read_text(encoding="utf-8")
                slug = Path(path).stem
                expected_group = (
                    "group: waffra-pr-" + slug
                    + "-${{ github.event.pull_request.number || github.run_id }}"
                )
                self.assertIn(expected_group, raw)
                self.assertIn(
                    "cancel-in-progress: ${{ github.event_name == 'pull_request' }}",
                    raw,
                )
                self.assertEqual(
                    len(re.findall(r"^concurrency:\s*$", raw, re.MULTILINE)), 1
                )
                self.assertLess(
                    raw.index("\nconcurrency:\n"), raw.index("\njobs:\n")
                )

    def test_cleanup_remains_trusted_and_scoped(self):
        raw = (ROOT / ".github/workflows/m453-superseded-pr-cleanup.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn("pull_request_target:", raw)
        self.assertIn("actions: write", raw)
        self.assertIn("dry_run:", raw)
        self.assertNotIn("actions/checkout", raw)
        self.assertIn("pr.head?.repo?.full_name !== repository", raw)
        self.assertIn("run.head_sha === latest", raw)
        self.assertIn("refreshed.data.head.sha !== latest", raw)
        self.assertIn("Date.parse(run.created_at) >= cutoff", raw)
        self.assertIn("run.event !== 'pull_request'", raw)
        self.assertIn("run.id === context.runId", raw)
        self.assertIn("linked.number === pr.number", raw)
        self.assertIn("run.head_branch !== branch", raw)
        self.assertIn("cancelWorkflowRun", raw)
        self.assertIn("event === 'workflow_dispatch' && inputs.dry_run !== 'false'", raw)


if __name__ == "__main__":
    unittest.main()
