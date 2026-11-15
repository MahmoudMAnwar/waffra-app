"""M946 smoke gate must fail closed if a feature loses runnable coverage."""
from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "qa"))
import m946_full_app_smoke_matrix as matrix


class FullAppSmokeMatrixTest(unittest.TestCase):
    def test_every_active_feature_has_two_real_test_files(self):
        report = matrix.validate(ROOT)
        self.assertGreaterEqual(report["features_count"], 30)
        self.assertGreaterEqual(report["test_files_count"], 40)
        self.assertEqual(set(report["groups"]), set(matrix.GROUPS))
        for name, (group, tests) in matrix.FEATURES.items():
            with self.subTest(feature=name):
                self.assertIn(group, matrix.GROUPS)
                self.assertGreaterEqual(len(tests), 2)
                self.assertTrue(all((ROOT / p).is_file() for p in tests))
                self.assertTrue(set(tests).issubset(matrix.group_tests(group)))

    def test_no_shard_may_become_empty_or_duplicate_entries(self):
        for group in matrix.GROUPS:
            tests = matrix.group_tests(group)
            self.assertGreaterEqual(len(tests), 10)
            self.assertEqual(len(tests), len(set(tests)))
        with self.assertRaises(ValueError):
            matrix.group_tests("skip")

    def test_missing_test_or_source_blocks_rather_than_claiming_pass(self):
        with tempfile.TemporaryDirectory() as temp:
            with self.assertRaisesRegex(ValueError, "uncovered"):
                matrix.validate(Path(temp))

    def test_hardware_and_private_backup_are_never_marked_automated_pass(self):
        report = matrix.validate(ROOT)
        limitations = " ".join(report["device_only_not_passed"]).lower()
        self.assertIn("android", limitations)
        self.assertIn("backup", limitations)
        self.assertIn("biometric", limitations)
        self.assertIn("sms", limitations)


    def test_stacked_feature_branch_pr_runs_real_three_shard_ci(self):
        workflow = (ROOT / ".github/workflows/m946-whole-app-feature-smoke.yml"
                    ).read_text(encoding="utf-8")
        self.assertIn("  pull_request:\n", workflow)
        pr_trigger = workflow.split("  pull_request:\n", 1)[1].split(
            "  push:\n", 1)[0]
        self.assertIn(
            "    types: [opened, synchronize, reopened, ready_for_review]",
            pr_trigger,
        )
        # Any feature-branch base must be included, not just PRs to main.
        self.assertNotIn("branches:", pr_trigger)
        self.assertNotIn("branches-ignore:", pr_trigger)
        self.assertIn("  push:\n    branches: [main]", workflow)
        self.assertIn("group: [money, experience, safety]", workflow)
        self.assertIn("github.event.pull_request.head.sha || github.sha", workflow)
        self.assertIn("--file-reporter", workflow)
        self.assertIn("m937_flutter_test_report.py", workflow)
        behavior = (ROOT / ".github/workflows/m550-behavior-contract-preflight.yml"
                    ).read_text(encoding="utf-8")
        preflight_trigger = behavior.split("  pull_request:\n", 1)[1].split(
            "  workflow_dispatch:\n", 1)[0]
        self.assertIn(
            "    types: [opened, synchronize, reopened, ready_for_review]",
            preflight_trigger,
        )
        self.assertNotIn("branches:", preflight_trigger)
        self.assertNotIn("branches-ignore:", preflight_trigger)
        self.assertIn("m550_behavior_contract_preflight.py", behavior)

if __name__ == "__main__":
    unittest.main()
