"""M925: M110 CI must scan actual declared Home Dart parts without weakening guards."""
from pathlib import Path
import unittest
from waffra_home_source import read_waffra_home_source

ROOT=Path(__file__).resolve().parents[2]
class M925RegisteredHomeFinanceSourcePreflightTest(unittest.TestCase):
    def test_m110_scans_real_registered_home_finance_source_and_denies_raw_direct_writes(self):
        workflow=(ROOT/'.github/workflows/m110-home-writer-source-authority.yml').read_text(encoding='utf-8')
        source=read_waffra_home_source(ROOT)
        for witness in (
            'from waffra_home_source import read_waffra_home_source',
            'home=read_waffra_home_source(Path.cwd())',
            "assert '_homeFinancePersistence.saveLegacy(' not in home",
            "assert '_homeFinancePersistence.commitConfirmedLegacySms(' not in home",
            "assert 'WaffraFinanceRoute.deleteAllTransactions' in home",
            "assert 'WaffraFinanceRoute.fullFinanceReset' in home",
            "assert 'WaffraFinanceRoute.bulkSmsConfirmedSave' in home",
            "assert \"part 'waffra_home_delete_all_transactions.part.dart';\" in main",
            "assert \"part 'waffra_home_sms_confirmation.part.dart';\" in main",
        ):
            self.assertIn(witness,workflow)
        for witness in (
            "WaffraFinanceRoute.deleteAllTransactions",
            "WaffraFinanceRoute.fullFinanceReset",
            "WaffraFinanceRoute.bulkSmsConfirmedSave",
            "_financeAuthority.commitConfirmedSms(",
        ):
            self.assertIn(witness,source)
        for prohibited in (
            "_homeFinancePersistence.saveLegacy(",
            "_homeFinancePersistence.commitConfirmedLegacySms(",
        ):
            self.assertNotIn(prohibited,source)
        self.assertNotIn("home=Path('lib/main.dart').read_text()",workflow)

    def test_m924_original_dart_string_witnesses_stay_unweakened(self):
        guard=(ROOT/'test/qa/m924_widget_shared_sms_registered_source_guard_test.py').read_text(encoding='utf-8')
        dart=(ROOT/'test/m108_home_widget_one_finance_writer_test.dart').read_text(encoding='utf-8')
        self.assertIn('self.assertIn(witness.replace("\'", "\\\\'"),test)',guard)
        self.assertIn("self.assertIn(witness,original)",guard)
        self.assertEqual(dart.count('final home=readWaffraMainSourceForContracts();'),2)
        self.assertIn("expect(home,isNot(contains('_homeFinancePersistence.commitConfirmedLegacySms(')));",dart)
if __name__=="__main__":unittest.main()
