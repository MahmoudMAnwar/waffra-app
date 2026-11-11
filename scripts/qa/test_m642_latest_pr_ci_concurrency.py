"""M642 / #563: latest-PR-only CI; keep trusted cleanup and main isolated."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PR = r"${{ github.event_name }}-${{ github.event.pull_request.number || github.run_id }}"
GROUPS = {
    "finance-full-regression.yml": "waffra-pr-finance-full-regression",
    "m103-same-sha-release-certification.yml": "waffra-pr-m103-same-sha-release-certification",
    "m160-main-reconciliation.yml": "waffra-pr-m160-main-reconciliation",
    "m550-behavior-contract-preflight.yml": "m550-contracts",
    "m147-final-main-review-gate.yml": "m147-main-review",
    "m274-production-ui-golden.yml": "m274-ui",
    "m282-combined-candidate.yml": "m282-candidate",
    "m340-continuous-financial-quality.yml": "m340-finance",
}

class LatestPRConcurrencyTests(unittest.TestCase):
    def test_expensive_jobs_supersede_same_pr_only(self):
        for name, prefix in GROUPS.items():
            with self.subTest(name=name):
                raw = (ROOT / ".github/workflows" / name).read_text(encoding="utf-8")
                groups = re.findall(r"(?m)^  group: (.+)$", raw)
                self.assertEqual(groups, [prefix + "-" + PR])
                self.assertIn("  cancel-in-progress: ${{ github.event_name == 'pull_request' }}", raw)
                self.assertNotIn("github.sha", groups[0])
                self.assertNotIn("github.ref", groups[0])
                self.assertNotIn("head.sha", groups[0])
                self.assertIn("  pull_request:", raw)
                self.assertIn("\njobs:\n", raw)

    def test_exact_sha_checkout_kept(self):
        for name in GROUPS:
            with self.subTest(name=name):
                raw = (ROOT / ".github/workflows" / name).read_text(encoding="utf-8")
                self.assertIn("ref: ${{ github.event.pull_request.head.sha || github.sha }}", raw)
        for name in ("finance-full-regression.yml",
                     "m103-same-sha-release-certification.yml"):
            raw = (ROOT / ".github/workflows" / name).read_text(encoding="utf-8")
            self.assertEqual(raw.count("uses: actions/checkout@v4"),
                             raw.count("ref: ${{ github.event.pull_request.head.sha || github.sha }}"))

    def test_m453_trusted_sweep_stays_alive_and_scoped(self):
        raw = (ROOT / ".github/workflows/m453-superseded-pr-cleanup.yml").read_text(encoding="utf-8")
        self.assertIn("pull_request_target:", raw)
        self.assertIn("  actions: write", raw)
        self.assertIn("  cancel-in-progress: false", raw)
        self.assertNotIn("uses: actions/checkout", raw)
        for guard in ("run.head_sha === latest",
                      "refreshed.data.head.sha !== latest",
                      "pr.head?.repo?.full_name !== repository",
                      "run.event !== 'pull_request'",
                      "run.head_branch !== branch",
                      "linked.number === pr.number",
                      "const maxPerSweep = 120;",
                      "const seenRuns = new Set();",
                      "event === 'workflow_dispatch' && inputs.dry_run !== 'false'"):
            self.assertIn(guard, raw)

if __name__ == "__main__":
    unittest.main()
