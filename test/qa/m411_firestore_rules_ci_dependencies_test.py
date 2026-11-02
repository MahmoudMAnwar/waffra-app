"""M411: the real Firestore rules job must install stable compatible packages."""
from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github/workflows/firestore-security-rules.yml"
PACKAGE = ROOT / "test/firebase/package.json"


class FirestoreRulesDependenciesTest(unittest.TestCase):
    def test_stable_compatible_node_and_pinned_packages(self):
        workflow = WORKFLOW.read_text(encoding="utf-8")
        package = json.loads(PACKAGE.read_text(encoding="utf-8"))
        self.assertIn("node-version: '24.12.0'", workflow)
        self.assertEqual(package["devDependencies"]["@firebase/rules-unit-testing"], "6.0.0")
        self.assertEqual(package["devDependencies"]["firebase"], "13.1.0")
        self.assertEqual(package["devDependencies"]["firebase-tools"], "15.34.1")
        self.assertEqual(package["overrides"]["@firebase/firestore"], "4.19.0")
        for dependency in package["devDependencies"].values():
            self.assertNotRegex(dependency, r"[~^*]|latest")

    def test_real_firestone_rules_emulator_and_assertions_not_bypassed(self):
        workflow = WORKFLOW.read_text(encoding="utf-8")
        test_source = (ROOT / "test/firebase/firestore.rules.test.mjs").read_text(
            encoding="utf-8")
        self.assertIn("npm --prefix test/firebase install --no-audit --no-fund", workflow)
        self.assertIn("firebase emulators:exec", workflow)
        self.assertIn("--only firestore", workflow)
        self.assertIn("'npm --prefix test/firebase test'", workflow)
        self.assertIn("assertFails", test_source)
        self.assertIn("assertSucceeds", test_source)
        self.assertNotIn("continue-on-error: true", workflow)
        self.assertNotIn("if: false", workflow)


if __name__ == "__main__":
    unittest.main()
