from pathlib import Path
import unittest

class Encrypted24RouteGateWiring(unittest.TestCase):
    def test_preflight_is_after_key_and_digest_before_bridge(self):
        binder=Path("lib/storage/waffra_production_finance_authority_binding.dart").read_text(encoding="utf-8")
        pos_key=binder.index("if (key == null || key.isEmpty)")
        pos_digest=binder.index("checkpoint.sourceDigest != evidence.storage.sourceDigest")
        pos_preflight=binder.index("WaffraFinance24RoutePreflight().inspect(")
        pos_bridge=binder.index("final bridge = WaffraVerifiedEncryptedFinanceBridge(")
        self.assertLess(pos_key,pos_digest)
        self.assertLess(pos_digest,pos_preflight)
        self.assertLess(pos_preflight,pos_bridge)
        self.assertIn("if (!routePreflight.allContractsAcceptEncrypted)",binder)
        self.assertIn("if (decision.automaticallyActivateSqlCipher)",binder)

    def test_preflight_never_grants_cutover(self):
        preflight=Path("lib/storage/waffra_finance_24_route_preflight.dart").read_text(encoding="utf-8")
        self.assertIn("productionCutoverAuthorized => false",preflight)
        self.assertIn("WaffraFinanceRoute.values",preflight)
        self.assertIn("audit.blockers",preflight)
        self.assertNotIn("setBool(",preflight)
        self.assertNotIn("customStatement(",preflight)

if __name__ == "__main__":
    unittest.main()
