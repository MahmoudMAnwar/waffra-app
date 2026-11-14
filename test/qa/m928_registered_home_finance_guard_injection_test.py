"""M928 verifies M340 real registered finance source and hostile part overrides."""
import importlib.util
import sys
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location("m340_source_exact",ROOT/"scripts/qa/m340_financial_quality_gate.py")
assert spec is not None and spec.loader is not None
gate=importlib.util.module_from_spec(spec)
sys.modules[spec.name]=gate
spec.loader.exec_module(gate)

class M928RealRegisteredFinanceAuthorityGuard(unittest.TestCase):
    def test_real_m340_preflight_preserves_all_original_verified_sms_witnesses(self):
        sources=gate.load_sources()
        self.assertIn("lib/waffra_home_sms_confirmation.part.dart",sources)
        self.assertIn("lib/waffra_home_entry_sheet.part.dart",sources)
        self.assertEqual(gate.audit_sources(sources),[])
        from waffra_home_source import read_waffra_home_source
        original=read_waffra_home_source(ROOT,overrides=sources)
        self.assertEqual(original.count("_financeAuthority.commitConfirmedSms("),2)
        for required in (
            "expectedAccountGeneration:chosen.generation",
            "expectedAccountGeneration:reviewedAccount.generation",
            "reviewSmsAccountLinks([trial],smsSender:sender)",
            "reviewedAccount?.ids?.single!=null",
            "allowDuplicateHashes:false",
            "WaffraSmsCurrencies.requiresReviewForSarLedger(message.text)",
            "_financeAuthority.saveCaptured(",
            "WaffraFinanceRoute.deleteAllTransactions",
        ):
            self.assertIn(required,original)

    def test_negative_mutations_of_genuine_registered_parts_cannot_pass_m340(self):
        source=gate.load_sources()
        cases=(
            ("lib/waffra_home_sms_confirmation.part.dart",
             "expectedAccountGeneration:chosen.generation",
             "expectedAccountGeneration:null"),
            ("lib/waffra_home_sms_confirmation.part.dart",
             "allowDuplicateHashes:false",
             "allowDuplicateHashes:true"),
            ("lib/waffra_home_entry_sheet.part.dart",
             "expectedAccountGeneration:reviewedAccount.generation",
             "expectedAccountGeneration:null"),
            ("lib/waffra_home_entry_sheet.part.dart",
             "WaffraSmsCurrencies.requiresReviewForSarLedger(message.text)",
             "false"),
        )
        for path,secure,unsafe in cases:
            with self.subTest(path=path,witness=secure):
                self.assertIn(secure,source[path])
                corrupted=dict(source)
                corrupted[path]=source[path].replace(secure,unsafe,1)
                self.assertNotEqual(gate.audit_sources(corrupted),[],
                                    msg="M340 failed to reject unsafe real part mutation")
        self.assertEqual(gate.audit_sources(source),[])
if __name__=="__main__":unittest.main()
