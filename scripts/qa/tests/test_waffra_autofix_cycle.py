"""M323: negative acceptance for autonomous repair gates (no network required)."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1] / "waffra_autofix_cycle.py"
spec = importlib.util.spec_from_file_location("waffra_autofix_cycle", SOURCE)
assert spec is not None and spec.loader is not None
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


class WaffraAutofixGuardTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.previous = os.getcwd()
        os.chdir(self.temp.name)
        subprocess.run(["git", "init", "-q"], check=True)
        subprocess.run(["git", "config", "user.name", "Waffra QA"], check=True)
        subprocess.run(["git", "config", "user.email", "qa@example.test"], check=True)
        Path("lib").mkdir()
        Path("test").mkdir()
        Path(".github/workflows").mkdir(parents=True)
        Path("lib/model.dart").write_text("const baseline = 1;\n")
        Path("test/model_test.dart").write_text("void main() {}\n")
        Path(".github/workflows/ci.yml").write_text("name: smoke\n")
        subprocess.run(["git", "add", "."], check=True)
        subprocess.run(["git", "commit", "-qm", "baseline"], check=True)

    def tearDown(self):
        os.chdir(self.previous)
        self.temp.cleanup()

    def test_small_dart_patch_is_accepted_and_exported(self):
        Path("lib/model.dart").write_text("const baseline = 2;\n")
        self.assertEqual(guard.changed_paths(), ["lib/model.dart"])
        guard.validate()
        patch_file = Path("waffra-autofix.patch")
        self.assertTrue(patch_file.exists())
        self.assertIn(b"baseline = 2", patch_file.read_bytes())

    def test_new_regression_dart_file_is_allowed(self):
        Path("test/new_regression_test.dart").write_text("void main() {}\n")
        guard.validate()
        self.assertIn(b"new_regression_test.dart",
                      Path("waffra-autofix.patch").read_bytes())

    def test_ci_workflow_edits_are_blocked(self):
        Path(".github/workflows/ci.yml").write_text("name: weakened gate\n")
        with self.assertRaisesRegex(ValueError, "Unsafe"):
            guard.changed_paths()

    def test_deleted_financial_dart_source_is_blocked(self):
        Path("lib/model.dart").unlink()
        with self.assertRaisesRegex(ValueError, "Deleting"):
            guard.changed_paths()

    def test_context_and_patch_artifacts_never_count_as_source(self):
        Path("waffra-autofix-context.md").write_text("CI says fix this\n")
        Path("waffra-autofix.patch").write_text("sample patch\n")
        self.assertEqual(guard.changed_paths(), [])
        with self.assertRaisesRegex(ValueError, "eligible"):
            guard.validate()

    def test_pending_older_failed_ci_blocks_a_new_fix_cycle(self):
        sha = "a" * 40
        response = {"total_count": 2, "workflow_runs": [
            {"id": 1, "name": "QA1", "status": "completed",
             "conclusion": "failure", "head_sha": sha, "event": "pull_request"},
            {"id": 2, "name": "QA2", "status": "queued",
             "conclusion": None, "head_sha": sha, "event": "pull_request"},
        ]}
        with patch.object(guard, "api", return_value=response):
            failed, reason = guard.failed_runs_for_sha(sha)
        self.assertIsNone(failed)
        self.assertIn("running or queued", reason)

    def test_all_completed_with_failure_is_eligible(self):
        sha = "b" * 40
        response = {"total_count": 3, "workflow_runs": [
            {"id": 10, "name": "QA1", "status": "completed",
             "conclusion": "failure", "head_sha": sha, "event": "pull_request"},
            {"id": 11, "name": "QA2", "status": "completed",
             "conclusion": "success", "head_sha": sha, "event": "pull_request"},
            {"id": 12, "name": "QA3", "status": "completed",
             "conclusion": "skipped", "head_sha": sha, "event": "pull_request"},
        ]}
        with patch.object(guard, "api", return_value=response):
            failed, reason = guard.failed_runs_for_sha(sha)
        self.assertEqual(reason, "")
        self.assertEqual(len(failed), 1)
        self.assertEqual(failed[0]["name"], "QA1")

    def test_forks_and_autofix_branches_are_rejected(self):
        prs = [
            {"number": 1, "head": {"ref": "fix/owner",
             "repo": {"full_name": guard.REPO}}, "base": {"ref": "main"}},
            {"number": 2, "head": {"ref": "fix/fork",
             "repo": {"full_name": "other/waffra-app"}},
             "base": {"ref": "main"}},
            {"number": 3, "head": {"ref": "autofix/replay",
             "repo": {"full_name": guard.REPO}}, "base": {"ref": "main"}},
        ]
        with patch.object(guard, "api", return_value=prs):
            found = guard.trusted_prs()
        self.assertEqual([p["number"] for p in found], [1])


if __name__ == "__main__":
    unittest.main()
