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


if __name__ == "__main__":
    unittest.main()
