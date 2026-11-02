"""M412 wiring: only impacted jobs execute on a changed PR commit."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
WF = ROOT / ".github/workflows"
SCOPED = [
  "m274-production-ui-golden.yml",
  "m295-compact-selection-ui.yml",
  "m283-compact-layout-tools-back-greetings.yml",
  "m277-ux-accessibility.yml",
  "m278-mobile-system-insets.yml",
  "m281-practical-tools.yml",
  "m287-receipt-ocr.yml",
  "m297-receipt-to-entry.yml",
  "m298-finance-validation.yml",
  "m302-cross-feature-input-qa.yml",
  "m303-m306-production-hardening.yml",
  "m371-goal-wallet-budget-android-regression.yml",
  "m290-country-reminders-multicurrency.yml",
  "m317-ondevice-ai-brain.yml",
  "m106-play-privacy-preflight.yml",
  "m107-account-deletion-crash-privacy.yml",
  "m108-home-widget-one-finance-commit.yml",
  "m109-verified-finance-authority.yml",
  "m110-home-writer-source-authority.yml",
  "m113-recovery-rollback-regression.yml",
  "m114-sqlcipher-projected-editor.yml",
  "m96-runtime-finance-cloud-integration.yml",
  "m98-encrypted-recovery-inventory.yml",
  "m99-manifest-last-cloud-sync.yml",
  "m266-sqlcipher-precutover-qa.yml",
  "m279-app-security-gates.yml",
  "m280-finance-quality-matrix.yml",
  "firestore-security-rules.yml"
]
ALWAYS_ON = [
    "android.yml",
    "m174-main-sha-postmerge.yml",
    "m340-continuous-financial-quality.yml",
    "finance-full-regression.yml",
]


class WorkflowWiringTest(unittest.TestCase):
    def test_scoped_jobs_gate_on_exact_changed_commit_without_removing_tests(self):
        for name in SCOPED:
            with self.subTest(workflow=name):
                source = (WF / name).read_text(encoding="utf-8")
                self.assertIn("  pull_request:", source)
                self.assertIn("    paths:", source)
                self.assertIn("  m412-impact:", source)
                self.assertIn("fetch-depth: 0", source)
                self.assertIn("scripts/qa/m412_pr_changed_impact.py", source)
                self.assertIn("needs.m412-impact.outputs.run == 'true'", source)
                jobs = source.split("jobs:", 1)[1]
                names = re.findall(r"(?m)^  ([a-zA-Z][\w-]*):\s*$", jobs)
                self.assertIn("m412-impact", names)
                for job in names:
                    if job == "m412-impact":
                        continue
                    block = jobs.split(f"  {job}:\n", 1)[1]
                    block = re.split(r"(?m)^  [a-zA-Z][\w-]*:\s*$",
                                     block, maxsplit=1)[0]
                    self.assertIn("    needs: m412-impact", block)
                    self.assertIn("    if: ${{ needs.m412-impact.outputs.run == 'true' }}", block)

    def test_full_financial_security_and_main_release_gates_stay_mandatory(self):
        for name in ALWAYS_ON:
            with self.subTest(workflow=name):
                workflow = (WF / name).read_text(encoding="utf-8")
                self.assertNotIn("m412-impact:", workflow)
        main = (WF / "android.yml").read_text(encoding="utf-8")
        self.assertIn("needs: [verify-all-tests, verify-same-sha-checks]", main)
        self.assertIn("flutter test --reporter expanded", main)


if __name__ == "__main__":
    unittest.main()
