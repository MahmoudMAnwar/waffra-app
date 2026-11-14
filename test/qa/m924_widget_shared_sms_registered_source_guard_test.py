"""M924 regression for unchanged original M636 Home/Widget writer tests."""
from pathlib import Path
import unittest
from waffra_home_source import read_waffra_home_source
ROOT=Path(__file__).resolve().parents[2]
class M924WidgetWriterRealSourceGuard(unittest.TestCase):
    def test_original_home_widget_writer_assertions_use_registered_source(self):
        test=(ROOT/'test/m108_home_widget_one_finance_writer_test.dart').read_text(encoding='utf-8')
        lib=(ROOT/'lib/main.dart').read_text(encoding='utf-8')
        original=read_waffra_home_source(ROOT)
        self.assertIn("import 'support/waffra_main_source.dart';",test)
        self.assertEqual(test.count('final home=readWaffraMainSourceForContracts();'),2)
        self.assertNotIn("final home=File('lib/main.dart').readAsStringSync();",test)
        for witness in (
            "await _ensureFinanceBound();",
            "_financeAuthority.commitConfirmedSms(",
            "WaffraFinanceRoute.bulkSmsConfirmedSave",
            "if(!mounted||!ready||waffraWidgetAction.value!='add')return;",
            "unawaited(entrySheet())",
            "if(!startup.encrypted)await const WaffraLiveLegacyFinanceGuard().requireLegacySource(p)",
        ):
            # Dart escapes nested single quotes in source-level assertions.
            # Check the same original witness without changing finance assertions.
            self.assertIn(witness.replace("'", "\\'"),test)
            self.assertIn(witness,original)
        self.assertIn("part 'waffra_home_sms_confirmation.part.dart';",lib)
        self.assertIn("part 'waffra_home_entry_sheet.part.dart';",lib)
        for witness in (
            "native,isNot(contains('commitConfirmedSms('))",
            "home,isNot(contains('_homeFinancePersistence.commitConfirmedLegacySms('))",
            "native,isNot(contains('FirebaseFirestore.instance'))",
            "native,isNot(contains('journal.prepare('))",
            "binding,isNot(contains('WaffraEncryptedStore.openShadow('))",
        ):
            self.assertIn(witness,test)
if __name__=='__main__':unittest.main()
