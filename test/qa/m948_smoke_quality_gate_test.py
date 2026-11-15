"""M948 CI quality gate mutation tests: no all-green skipped/unverified report."""
import copy
import sys
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "qa"))
from m948_smoke_quality_gate import validate

SHA = "a" * 40
BASE = {
    "exact_sha": SHA, "complete": True, "runner_success": True,
    "passed_gate": True, "passed": 151, "failed": 0, "skipped": 0,
    "total": 151, "issues": [], "failure_group_estimate": 0,
    "physical_android_verified": False,
    "production_release_approved": False,
}


class M948NoFalseGreenTest(unittest.TestCase):
    def test_legitimate_evidence_passes_but_never_claims_android(self):
        for shard in ("money", "experience", "safety"):
            result = validate(copy.deepcopy(BASE), sha=SHA, group=shard)
            self.assertEqual(result["passed"], 151)
            self.assertEqual(result["skipped"], 0)
            self.assertFalse(result["android_uat_passed"])

    def test_skip_is_not_success_even_if_runner_looks_green(self):
        report = copy.deepcopy(BASE)
        report.update(skipped=1, passed=150, total=151)
        with self.assertRaisesRegex(ValueError, "skipped"):
            validate(report, sha=SHA, group="safety")

    def test_stale_commit_and_wrong_shard_fail_closed(self):
        with self.assertRaisesRegex(ValueError, "stale SHA"):
            validate(copy.deepcopy(BASE), sha="b" * 40, group="money")
        with self.assertRaises(ValueError):
            validate(copy.deepcopy(BASE), sha=SHA, group="dummy")

    def test_incomplete_runner_and_missing_case_data_fail_closed(self):
        for alteration in (
            {"complete": False}, {"runner_success": False},
            {"passed_gate": False}, {"passed": 0, "total": 0},
            {"failed": 1, "passed": 150, "total": 151},
            {"issues": ["unfinished_test"]},
            {"physical_android_verified": True},
            {"production_release_approved": True},
            {"failure_group_estimate": 1},
            {"skipped": None},
        ):
            with self.subTest(alteration=alteration), self.assertRaises(ValueError):
                report = copy.deepcopy(BASE)
                report.update(alteration)
                validate(report, sha=SHA, group="experience")


if __name__ == "__main__":
    unittest.main()
