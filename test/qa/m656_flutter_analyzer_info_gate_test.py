"""M656: only information-level Flutter SDK deprecations are non-fatal.

M429 and M417 must still analyze their exact original files, fail on
warnings/errors, run all existing regression tests and preserve M385 scope.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
WF = ROOT / ".github" / "workflows"

M429_ANALYZED = (
    "lib/main.dart", "lib/waffra_local_phone_credentials.dart",
    "lib/waffra_local_account_migration.dart",
    "lib/waffra_mandatory_biometric_gate.dart", "lib/waffra_biometrics.dart",
    "lib/waffra_auto_sms.dart", "lib/waffra_sms_cloud_service.dart",
    "lib/waffra_cloudflare_sms_gateway.dart", "lib/waffra_auto_sms_consent.dart",
)
M417_ANALYZED = (
    "lib/main.dart", "lib/waffra_auto_sms.dart", "lib/waffra_auto_sms_policy.dart",
    "lib/waffra_auto_sms_consent.dart", "lib/waffra_messages.dart",
    "lib/waffra_bank_sms_facts.dart", "lib/waffra_sms_cloud_service.dart",
    "lib/waffra_sms_cloud_redactor.dart", "lib/waffra_cloudflare_sms_gateway.dart",
)

class M656AnalyzerCompatibilityTests(unittest.TestCase):
    def test_both_full_analyzers_keep_errors_and_warnings_fatal(self):
        for filename, expected in (
            ("m429-integration-smoke.yml", M429_ANALYZED),
            ("m417-auto-bank-sms.yml", M417_ANALYZED),
        ):
            with self.subTest(filename=filename):
                source = (WF / filename).read_text(encoding="utf-8")
                commands = [line.strip() for line in source.splitlines()
                            if "flutter analyze" in line]
                self.assertEqual(len(commands), 1)
                command = commands[0]
                self.assertIn("flutter analyze --no-fatal-infos lib/main.dart", command)
                self.assertNotIn("--no-fatal-warnings", command)
                self.assertNotIn("|| true", command)
                self.assertNotIn("--no-fatal-errors", command)
                self.assertNotIn("continue-on-error: true", source)
                self.assertIn("m385_approved_change_guard.py", source)
                args = command.split("flutter analyze --no-fatal-infos ", 1)[1].split()
                self.assertEqual(tuple(args), expected)

    def test_m429_mandatory_auth_and_sms_cases_still_run(self):
        s = (WF / "m429-integration-smoke.yml").read_text(encoding="utf-8")
        for path in (
            "test/m422_phone_only_auth_entry_test.dart",
            "test/m424_mandatory_biometrics_test.dart",
            "test/m426_local_phone_credentials_test.dart",
            "test/m428_local_account_migration_test.dart",
            "test/m417_sms_first_run_test.dart",
            "test/m423_cloudflare_sms_gateway_test.dart",
            "test/m429_sms_phone_integration_test.dart",
        ):
            self.assertIn(path, s)
        self.assertIn("node --test cloudflare/waffra_sms_worker.test.mjs", s)

    def test_m417_sms_and_native_finance_cases_still_run(self):
        s = (WF / "m417-auto-bank-sms.yml").read_text(encoding="utf-8")
        for path in (
            "test/m417_sms_first_run_test.dart",
            "test/waffra_auto_sms_policy_test.dart",
            "test/waffra_bank_sms_facts_test.dart",
            "test/waffra_sms_cloud_redactor_test.dart",
            "test/m423_cloudflare_sms_gateway_test.dart",
        ):
            self.assertIn(path, s)
        for marker in ("android-sms-native-compile:", "flutter test --reporter expanded",
                       "m385_approved_change_guard.py"):
            self.assertIn(marker, s)

if __name__ == "__main__":
    unittest.main()
