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
            "lib/main.dart", "_financeAuthority.commitConfirmedSms(",
            "_homeFinancePersistence.commitConfirmedLegacySms(",
            "SMS verified authority bypass")

    def test_detects_foreign_currency_bypass(self):
        self.assert_detects_change(
            "lib/main.dart",
            "WaffraSmsCurrencies.requiresReviewForSarLedger(messages[index])",
            "false",
            "foreign currency guard removal")

    def test_detects_fx_preview_ledger_write(self):
        self.assert_detects_change(
            "lib/main.dart",
            "WaffraForeignCurrencyPreview.show(context,",
            "persist(); WaffraForeignCurrencyPreview.show(context,",
            "FX preview unexpected finance write")

    def test_detects_ai_money_hallucination_gate_removed(self):
        self.assert_detects_change(
            "lib/waffra_smart_features.dart",
            "hasUnverifiedMoneyClaim(cleaned)",
            "false",
            "unverified model-derived amounts")

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
