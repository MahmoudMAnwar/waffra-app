"""M902: original finance CI assertions inspect registered real Home Dart parts.

Read-only QA: does not mutate a finance ledger or qualify physical-device
Backup/Restore. Missing registered parts must fail closed in the shared helper.
"""
from pathlib import Path
import unittest

from waffra_home_source import read_waffra_home_source

ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = (
    ".github/workflows/finance-full-regression.yml",
    ".github/workflows/m96-runtime-finance-cloud-integration.yml",
    ".github/workflows/m109-verified-finance-authority.yml",
)


class M902RealFinanceWorkflowSourceGuard(unittest.TestCase):
    def test_all_existing_finance_workflows_read_real_registered_home_parts(self):
        for path in WORKFLOWS:
            with self.subTest(path=path):
                workflow = (ROOT / path).read_text(encoding="utf-8")
                self.assertIn("from waffra_home_source import read_waffra_home_source", workflow)
                self.assertIn("sys.path.insert(0, str(Path('test/qa').resolve()))", workflow)
                self.assertIn("read_waffra_home_source()", workflow)
                self.assertIn("assert '_financeAuthority.commitConfirmedSms(' not in widget", workflow)
                self.assertNotIn("app=Path('lib/main.dart').read_text()", workflow)
                self.assertNotIn("app = Path('lib/main.dart').read_text()", workflow)
                self.assertNotIn("main=Path('lib/main.dart').read_text()", workflow)

    def test_same_real_home_finance_source_retains_two_confirmed_sms_writers(self):
        original = read_waffra_home_source(ROOT)
        self.assertEqual(original.count("_financeAuthority.commitConfirmedSms("), 2)
        self.assertIn("WaffraFinanceRoute.bulkSmsConfirmedSave", original)
        self.assertIn("_financeAuthority.saveCaptured(", original)
        self.assertIn("await _ensureFinanceBound();", original)


if __name__ == "__main__":
    unittest.main()
