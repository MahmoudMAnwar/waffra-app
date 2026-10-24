import tempfile
import unittest
from pathlib import Path

from m106_play_release_preflight import inspect


class PlayReleasePreflightTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="waffra-m106-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / ".github/workflows").mkdir(parents=True)
        (self.root / "lib/diagnostics").mkdir(parents=True)
        (self.root / "docs/release").mkdir(parents=True)
        (self.root / "pubspec.yaml").write_text("firebase_auth: ^6.0.0")
        (self.root / ".github/workflows/android.yml").write_text(
            "Configure and validate Waffra release signing\n"
            "flutter build appbundle\ntargetSdk = 36\n"
        )
        (self.root /
         "lib/diagnostics/waffra_private_release_diagnostics.dart").write_text(
            "this.userConsented = false\n"
            "this.releaseConfigurationVerified = false\n"
        )
        for name in [
            "PRIVACY_POLICY_AR_DRAFT.md",
            "PRIVACY_POLICY_EN_DRAFT.md",
            "PLAY_STORE_LISTING_AR_EN_DRAFT.md",
            "PLAY_DATA_SAFETY_REVIEW.md",
            "PRODUCTION_GO_LIVE_CHECKLIST.md",
        ]:
            (self.root / "docs/release" / name).write_text("draft")

    def test_candidate_prepare_can_pass_but_production_is_always_blocked(self):
        result = inspect(self.root)
        self.assertTrue(result["hasDraftPolicyFiles"])
        self.assertTrue(result["hasCandidateAabJob"])
        self.assertTrue(result["hasDefaultOffDiagnosticBoundary"])
        self.assertFalse(result["releaseReady"])
        self.assertTrue(result["auditOnly"])
        self.assertFalse(result["productionDataMigration"])
        self.assertFalse(result["firebaseRulesDeployed"])

    def test_missing_aab_api_target_is_not_considered_ready(self):
        (self.root / ".github/workflows/android.yml").write_text(
            "Configure and validate Waffra release signing\n"
            "flutter build appbundle\ntargetSdk = 35\n"
        )
        report = inspect(self.root)
        self.assertFalse(report["hasCandidateAabJob"])
        self.assertIn("android_api36_signed_aab_pipeline_not_verified",
                      report["blockers"])

    def test_unverified_opt_in_is_a_mandatory_failure(self):
        (self.root /
         "lib/diagnostics/waffra_private_release_diagnostics.dart").write_text(
            "this.userConsented = true\n"
            "this.releaseConfigurationVerified = true\n"
        )
        report = inspect(self.root)
        self.assertFalse(report["hasDefaultOffDiagnosticBoundary"])
        self.assertIn("privacy_diagnostics_allowlist_not_verified",
                      report["blockers"])

    def test_policy_drafts_do_not_masquerade_as_public_urls(self):
        report = inspect(self.root)
        self.assertIn("public_https_privacy_policy_not_published_or_approved",
                      report["blockers"])
        self.assertIn("external_and_in_app_account_deletion_unverified",
                      report["blockers"])
        self.assertIn("physical_phone_install_google_signin_unverified",
                      report["blockers"])

    def test_no_crashlytics_dependency_never_passes_monitoring_review(self):
        self.assertIn("crashlytics_sdk_and_native_opt_in_not_integrated",
                      inspect(self.root)["blockers"])


if __name__ == "__main__":
    unittest.main()
