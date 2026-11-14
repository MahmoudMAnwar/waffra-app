"""M340 fail-closed tests: deliberately mutate each critical finance contract."""
from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "scripts/qa/m340_financial_quality_gate.py"
SPEC = importlib.util.spec_from_file_location("m340_gate", MODULE_PATH)
assert SPEC and SPEC.loader
gate = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = gate
SPEC.loader.exec_module(gate)


class FinancialQualityGateTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = gate.load_sources()

    def test_real_source_contract_is_wired(self):
        self.assertEqual(gate.audit_sources(self.source), [])

    def assert_detects_change(self, path, current, mutated, label):
        self.assertIn(current, self.source[path])
        changed = dict(self.source)
        changed[path] = changed[path].replace(current, mutated, 1)
        errors = gate.audit_sources(changed)
        self.assertTrue(errors, f"Gate missed unsafe {label}")

    def test_detects_finance_authority_bypass(self):
        self.assert_detects_change(
            "lib/waffra_home_sms_confirmation.part.dart", "_financeAuthority.commitConfirmedSms(",
            "_homeFinancePersistence.commitConfirmedLegacySms(",
            "SMS verified authority bypass")

    def test_new_sms_confirmation_cannot_drop_account_witness_or_hash(self):
        self.assert_detects_change(
            "lib/waffra_home_sms_confirmation.part.dart",
            "expectedAccountGeneration:chosen.generation",
            "expectedAccountGeneration:null",
            "quick SMS account-generation bypass")
        self.assert_detects_change(
            "lib/waffra_home_sms_confirmation.part.dart", "allowDuplicateHashes:false",
            "allowDuplicateHashes:true", "duplicate bank debit bypass")

    def test_detects_foreign_currency_bypass(self):
        self.assert_detects_change(
            "lib/waffra_home_entry_sheet.part.dart",
            "WaffraSmsCurrencies.requiresReviewForSarLedger(message.text)",
            "false",
            "foreign currency guard removal")

    def test_detects_fx_preview_ledger_write(self):
        # M932: the production preview moved to a registered Dart part.
        # Mutate that actual source so the hostile test cannot pass by
        # checking obsolete raw main.dart or ignoring an untracked override.
        self.assert_detects_change(
            "lib/waffra_home_fx_preview.part.dart",
            "WaffraForeignCurrencyPreview.show(context,",
            "persist(); WaffraForeignCurrencyPreview.show(context,",
            "FX preview unexpected finance write")
        self.assert_detects_change(
            "lib/waffra_home_fx_preview.part.dart",
            "WaffraForeignCurrencyPreview.show(context,",
            "saveCaptured(); WaffraForeignCurrencyPreview.show(context,",
            "FX preview unauthorized captured-finance write")

    def test_detects_retired_qwen_tools_reintroduced(self):
        self.assertNotIn("WaffraOnDeviceQwen",
                         self.source["lib/waffra_smart_features.dart"])
        self.assertNotIn("WaffraAiModelGate",
                         self.source["lib/waffra_smart_features.dart"])
        for unsafe in ("WaffraOnDeviceQwen",
                       "WaffraAiFinanceCoach.askWaffra",
                       "waffra-local-ai-opt-in"):
            mutated = dict(self.source)
            mutated["lib/waffra_smart_features.dart"] += "\n// " + unsafe + "\n"
            self.assertTrue(gate.audit_sources(mutated),unsafe)

    def test_detects_sms_editor_account_generation_bypass(self):
        self.assert_detects_change(
            "lib/waffra_home_entry_sheet.part.dart",
            "expectedAccountGeneration:reviewedAccount.generation",
            "expectedAccountGeneration:null",
            "surviving SMS editor account witness bypass")

    def test_detects_fx_consent_bypass(self):
        self.assert_detects_change(
            "lib/waffra_foreign_currency_preview.dart",
            "if(accepted!=true)return null;",
            "if(false)return null;",
            "FX user approval bypass")

    def test_detects_missing_explicit_approval_button(self):
        self.assert_detects_change(
            "lib/waffra_foreign_currency_preview.dart",
            "onPressed:()=>Navigator.pop(dialog,true)",
            "onPressed:()=>Navigator.pop(dialog,false)",
            "FX confirmation action removed")

    def test_detects_production_sqlcipher_cutover(self):
        self.assert_detects_change(
            "lib/storage/waffra_production_cutover_release_gate.dart",
            "automaticallyActivateSqlCipher => false",
            "automaticallyActivateSqlCipher => true",
            "unauthorized production cutover")

    def test_detects_original_currency_precision_change(self):
        self.assert_detects_change(
            "lib/waffra_sms_multicurrency_review.dart",
            "minorTotals",
            "floatingSourceTotals",
            "integer minor-unit accounting")


if __name__ == "__main__":
    unittest.main()
