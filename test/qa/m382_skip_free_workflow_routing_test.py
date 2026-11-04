"""M382 — avoid misleading skipped PR checks without erasing safety gates."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
WF = ROOT / ".github" / "workflows"


def source(name: str) -> str:
    return (WF / name).read_text(encoding="utf-8")


class SkipFreeWorkflowRoutingTest(unittest.TestCase):
    def test_m174_preflight_still_required_on_pr_and_main(self):
        preflight = source("m174-main-sha-postmerge.yml")
        self.assertIn("name: M174 Main SHA Post-Merge SQLCipher Regression", preflight)
        self.assertIn("  pull_request:", preflight)
        self.assertIn("  push:", preflight)
        self.assertIn("  pinned-no-go-preflight:", preflight)
        self.assertIn("m173_production_release_negative_matrix_test.dart", preflight)
        self.assertNotIn("main-arm64-compile:", preflight)
        self.assertNotIn("if: github.event_name == 'push'", preflight)

    def test_m174_native_compile_preserved_only_for_main(self):
        native = source("m174-main-arm64-compile.yml")
        self.assertIn("  push:", native)
        self.assertIn("branches: [main]", native)
        self.assertIn("  workflow_dispatch:", native)
        self.assertNotIn("  pull_request:", native)
        self.assertIn("  main-arm64-compile:", native)
        self.assertIn("flutter build apk --release --no-pub --target-platform android-arm64", native)
        self.assertIn("m174-main-arm64-ci-apk-not-production-certified", native)
        self.assertIn("not real-device or store proof", native)

    def test_full_finance_suite_still_runs_for_general_prs(self):
        full = source("finance-full-regression.yml")
        self.assertIn("  pull_request:", full)
        self.assertIn("  flutter-ui-and-finance:", full)
        self.assertIn("dart analyze lib/storage test/storage", full)
        self.assertIn("flutter test test/ --reporter expanded", full)
        self.assertIn("Encrypted screen mutation requires a verified atomic SQL projection writer.", full)
        self.assertNotIn("  android-finance-migration-rehearsal:", full)

    def test_finance_android_rehearsal_remains_available_without_skip(self):
        android = source("finance-android-migration-rehearsal.yml")
        self.assertNotIn("  pull_request:", android)
        self.assertIn("  workflow_dispatch:", android)
        self.assertIn("'feature/storage-cutover-readiness-m60'", android)
        self.assertIn("'integration/m160-reconcile-main-m158-release-gate-20261023'", android)
        self.assertIn("  android-finance-migration-rehearsal:", android)
        self.assertNotIn("    if:", android)
        self.assertNotIn("    needs:", android)
        # The old same-run dependency is replaced by exhaustive source tests.
        self.assertIn("flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings", android)
        self.assertIn("flutter test test/ --reporter expanded", android)
        self.assertIn("reactivecircus/android-emulator-runner@v2", android)
        self.assertIn("live_finance_migration_receipts_android_test.dart", android)
        self.assertIn("Confirm production cutover remains disabled", android)

    def test_historical_m268_never_triggers_a_main_pr_skip(self):
        m268 = source("m268-smart-features.yml")
        self.assertNotIn("  pull_request:", m268)
        self.assertIn("  workflow_dispatch:", m268)
        self.assertIn("'feature/m268-all-ten-smart-finance-illustrations-today-20261027'", m268)
        self.assertIn("  ten-tools-calendar-illustrations:", m268)
        self.assertNotIn("if: github.event_name != 'pull_request'", m268)
        self.assertIn("python3 scripts/qa/m268_scope_review.py", m268)
        self.assertIn("test/m268_smart_features_ten_calendar_art_test.dart", m268)
        self.assertIn("test/storage/m201_24_route_no_false_production_proof_test.dart", m268)

    def test_main_release_gates_unchanged(self):
        release = source("android.yml")
        self.assertIn("needs: [verify-all-tests, verify-same-sha-checks]", release)
        self.assertIn("M340 Continuous Financial Quality Gate (Exact SHA, No Cutover)", release)
        self.assertIn("M174 Main SHA Post-Merge SQLCipher Regression", release)
        self.assertIn("Run every Flutter regression including future test files", release)
        self.assertIn("flutter test --reporter expanded", release)
        self.assertIn("Verify final APK uses Firebase-registered Waffra release signing", release)
        self.assertIn("Build Android App Bundle candidate for Google Play internal testing", release)


if __name__ == "__main__":
    unittest.main()
