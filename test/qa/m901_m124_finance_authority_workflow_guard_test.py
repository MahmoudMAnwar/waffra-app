"""M901: preserve the real SQLCipher/SMS witness in M124 after Home part refactor.

Source-only regression: it does not certify Android or production finance cutover.
"""
from pathlib import Path
import unittest
from waffra_home_source import read_waffra_home_source

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github/workflows/m124-main-integration-audit.yml"


class M901FinanceAuthorityWorkflowGuard(unittest.TestCase):
    def test_m124_keeps_original_positive_and_negative_finance_guards(self):
        workflow = WORKFLOW.read_text(encoding="utf-8")
        block = workflow.split(
            "      - name: Ensure no implicit SQLCipher switch or unverified receipt UI mount\n"
        )
        self.assertEqual(len(block), 2)
        source = block[1].split("\n  encrypted-finance-regression:", 1)[0]
        self.assertIn("from waffra_home_source import read_waffra_home_source", source)
        self.assertIn("main=read_waffra_home_source()", source)
        self.assertNotIn("main=Path('lib/main.dart').read_text()", source)
        for required in (
            "assert 'WaffraVerifiedReceiptPanel(' not in main",
            "assert 'WaffraEncryptedFinanceSession(' not in main",
            "assert 'this.experimentalEnabled = false' in bridge",
            "assert 'this.encryptedSqlWitnessActive = false' in authority",
            "assert 'this.externalSourceWitnessActive = false' in authority",
            "assert 'this.verifiedKeyRecoveryInDevice = false' in authority",
            "assert 'automaticallyActivateSqlCipher => false' in release",
            "assert '_financeAuthority.commitConfirmedSms(' in main",
            "assert '_financeAuthority.commitConfirmedSms(' not in widget",
            "assert 'await _ensureFinanceBound();' in main",
        ):
            self.assertIn(required, source, required)

    def test_actual_original_sms_finance_writer_is_registered_once(self):
        main = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
        part = (ROOT / "lib/waffra_home_sms_confirmation.part.dart").read_text(
            encoding="utf-8")
        self.assertEqual(main.count("part 'waffra_home_sms_confirmation.part.dart';"), 1)
        self.assertTrue(part.startswith("part of 'main.dart';"))
        self.assertIn("_financeAuthority.commitConfirmedSms(", part)
        original = read_waffra_home_source(ROOT)
        self.assertIn("_financeAuthority.commitConfirmedSms(", original)
        self.assertIn("await _ensureFinanceBound();", original)


if __name__ == "__main__":
    unittest.main()
