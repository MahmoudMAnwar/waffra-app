import sys
import tempfile
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from m171_release_candidate_source_audit import inspect

ROOT = Path(__file__).resolve().parents[2]

class M171ReleaseCandidateTests(unittest.TestCase):
    def test_current_candidate_source_passes_without_claiming_aab_approved(self):
        report = inspect(ROOT)
        self.assertTrue(report["sourcePolicyConsistent"], report["sourceChecks"])
        self.assertFalse(report["aabSignedAndInstalledOnPhone"])
        self.assertFalse(report["readyForProduction"])

    def test_unsigned_or_production_deploy_workflow_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix="waffra-m171-") as tmp:
            root = Path(tmp)
            (root / ".github/workflows").mkdir(parents=True)
            for name in ("pubspec.yaml", ".github/workflows/android.yml"):
                target = root / name
                target.write_text((ROOT / name).read_text(encoding="utf-8"),
                                  encoding="utf-8")
            path = root / ".github/workflows/android.yml"
            path.write_text(path.read_text().replace(
                'signingConfigs.getByName("waffraRelease")',
                'signingConfigs.getByName("debug")') + "\nfastlane supply\n")
            report = inspect(root)
            self.assertFalse(report["sourcePolicyConsistent"])
            self.assertFalse(report["sourceChecks"]["no_debug_release_signing"])
            self.assertFalse(report["sourceChecks"]["no_play_production_publish_action"])

if __name__ == "__main__":
    unittest.main()
