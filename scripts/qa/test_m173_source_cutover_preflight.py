import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from m173_source_cutover_preflight import ROOT, inspect


class ProductionCutoverPreflightTests(unittest.TestCase):
    def test_current_staging_never_approves_real_production(self):
        report = inspect(ROOT)
        self.assertTrue(report["sourceGatePass"], report["sourceChecks"])
        self.assertEqual(report["financeRouteCount"], 24)
        self.assertFalse(report["releaseReady"])
        self.assertFalse(report["productionSqlCipherActivated"])
        self.assertFalse(report["userDataMigrationAttempted"])
        self.assertIn("signed_final_sha_android_device_test_missing", report["hardBlockers"])

    def test_no_automatic_source_activation_regression(self):
        with tempfile.TemporaryDirectory(prefix="waffra-m173-") as tmp:
            folder = Path(tmp)
            needed = [
                "lib/storage/waffra_production_finance_routing_gate.dart",
                "lib/storage/waffra_runtime_finance_route_contract.dart",
                "lib/storage/waffra_production_cutover_release_gate.dart",
                "lib/storage/waffra_finance_source_cutover_policy.dart",
                "lib/storage/waffra_production_finance_source_guard.dart",
                "lib/main.dart",
                "docs/release/PRIVACY_POLICY_EN_DRAFT.md",
            ]
            for name in needed:
                target = folder / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text((ROOT / name).read_text(encoding="utf-8"), encoding="utf-8")

            gate = folder / "lib/storage/waffra_production_cutover_release_gate.dart"
            gate.write_text(gate.read_text().replace(
                "bool get automaticallyActivateSqlCipher => false;",
                "bool get automaticallyActivateSqlCipher => true;",
            ))
            result = inspect(folder)
            self.assertFalse(result["sourceGatePass"])
            self.assertFalse(result["releaseReady"])
            self.assertFalse(result["sourceChecks"]["cutover_release_never_automatic"])


if __name__ == "__main__":
    unittest.main()
