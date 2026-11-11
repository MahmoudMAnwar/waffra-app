"""M548 / M642: preserve exact PR SHA testing while superseding obsolete CI."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FILES = (
 ".github/workflows/finance-full-regression.yml",
 ".github/workflows/m103-same-sha-release-certification.yml",
 ".github/workflows/m147-final-main-review-gate.yml",
 ".github/workflows/m160-main-reconciliation.yml",
 ".github/workflows/m274-production-ui-golden.yml",
 ".github/workflows/m282-combined-candidate.yml",
 ".github/workflows/m340-continuous-financial-quality.yml",
)

class M548HeadConcurrencyTests(unittest.TestCase):
 def test_full_suite_and_merge_gates_supersede_only_same_pr(self):
  for path in FILES:
   with self.subTest(path=path):
    s = (ROOT / path).read_text(encoding="utf-8")
    groups = re.findall(r"^  group: ([^\n]+)$", s, re.MULTILINE)
    self.assertEqual(len(groups), 1)
    self.assertIn("${{ github.event_name }}", groups[0])
    self.assertIn("${{ github.event.pull_request.number || github.run_id }}", groups[0])
    self.assertNotIn("github.event.pull_request.head.sha", groups[0])
    self.assertNotIn("github.ref", groups[0])
    self.assertEqual(len(re.findall(r"^concurrency:$", s, re.MULTILINE)), 1)
    self.assertLess(s.index("\nconcurrency:\n"), s.index("\njobs:\n"))
    self.assertIn(
     "  cancel-in-progress: ${{ github.event_name == 'pull_request' }}", s
    )
    self.assertIn(
     "ref: ${{ github.event.pull_request.head.sha || github.sha }}", s
    )

 def test_trusted_cleanup_still_rejects_current_sha_and_unlinked_runs(self):
  s = (ROOT / ".github/workflows/m453-superseded-pr-cleanup.yml").read_text(
   encoding="utf-8"
  )
  for literal in (
   "run.head_sha === latest",
   "refreshed.data.head.sha !== latest",
   "run.event !== 'pull_request'",
   "run.head_branch !== branch",
   "linked.number === pr.number",
   "pr.head?.repo?.full_name !== repository",
   "const maxPerSweep = 120;",
   "  cancel-in-progress: false",
  ):
   self.assertIn(literal, s)
  self.assertIn("pull_request_target:", s)
  self.assertNotIn("uses: actions/checkout", s)

if __name__ == "__main__":
 unittest.main()
