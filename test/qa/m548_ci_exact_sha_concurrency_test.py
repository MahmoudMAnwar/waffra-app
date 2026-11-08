"""M548: CI cancellation isolation for exact-head performance and finance tests."""
import re
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
FILES=(
 ".github/workflows/finance-full-regression.yml",
 ".github/workflows/m103-same-sha-release-certification.yml",
 ".github/workflows/m147-final-main-review-gate.yml",
 ".github/workflows/m160-main-reconciliation.yml",
 ".github/workflows/m274-production-ui-golden.yml",
 ".github/workflows/m282-combined-candidate.yml",
 ".github/workflows/m340-continuous-financial-quality.yml",
)

class M548HeadConcurrencyTests(unittest.TestCase):
 def test_full_suite_and_merge_gates_cannot_cross_cancel_sha(self):
  for path in FILES:
   with self.subTest(path=path):
    s=(ROOT/path).read_text(encoding="utf-8")
    groups=re.findall(r"^  group: ([^\n]+)$",s,re.MULTILINE)
    self.assertEqual(len(groups),1)
    self.assertIn("${{ github.event.pull_request.head.sha || github.sha }}",groups[0])
    self.assertIn("github.event.pull_request.number ||",groups[0])
    self.assertEqual(len(re.findall(r"^concurrency:$",s,re.MULTILINE)),1)
    self.assertLess(s.index("\nconcurrency:\n"),s.index("\njobs:\n"))

 def test_trusted_cleanup_still_rejects_current_sha_and_unlinked_runs(self):
  s=(ROOT/".github/workflows/m453-superseded-pr-cleanup.yml").read_text(encoding="utf-8")
  for literal in ("run.head_sha === latest",
                  "refreshed.data.head.sha !== latest",
                  "run.event !== 'pull_request'",
                  "run.head_branch !== branch",
                  "linked.number === pr.number"):
   self.assertIn(literal,s)

if __name__=="__main__":
 unittest.main()
