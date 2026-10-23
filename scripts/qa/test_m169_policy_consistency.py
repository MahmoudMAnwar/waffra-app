import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from m169_policy_consistency import inspect

REPO = Path(__file__).resolve().parents[2]

class PolicyConsistencyTests(unittest.TestCase):
    def test_current_bilingual_docs_match_declared_sdk_without_claiming_publication(self):
        report = inspect(REPO)
        self.assertTrue(report["sourceConsistencyPassed"], report["blockers"])
        self.assertFalse(report["publicationVerified"])
        self.assertFalse(report["productionApproved"])
        self.assertIn("play_console_data_safety_answers_not_submitted_or_checked",
                      report["blockers"])

    def test_stale_english_no_sdk_claim_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix="waffra-m169-") as work:
            root = Path(work)
            needed = [
                "pubspec.yaml",
                "docs/release/PRIVACY_POLICY_AR_DRAFT.md",
                "docs/release/PRIVACY_POLICY_EN_DRAFT.md",
                "docs/release/PLAY_DATA_SAFETY_REVIEW.md",
                "lib/diagnostics/waffra_crashlytics_opt_in.dart",
                ".github/workflows/android.yml",
            ]
            for name in needed:
                dst = root / name
                dst.parent.mkdir(parents=True, exist_ok=True)
                dst.write_text((REPO / name).read_text(encoding="utf-8"),
                               encoding="utf-8")
            path = root / "docs/release/PRIVACY_POLICY_EN_DRAFT.md"
            path.write_text(path.read_text().replace(
                "The Firebase Crashlytics SDK **is declared**",
                "Firebase is optional"), encoding="utf-8")
            report = inspect(root)
            self.assertFalse(report["sourceConsistencyPassed"])
            self.assertIn("english_crash_sdk_disclosed", report["blockers"])

if __name__ == "__main__":
    unittest.main()
