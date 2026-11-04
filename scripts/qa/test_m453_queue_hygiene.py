"""M453 regression: supersession never cancels main or unrelated PR jobs."""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "docs/qa/approved_change_scope.json"


class M453QueueSafetyTests(unittest.TestCase):
    def test_exact_pr_concurrency_for_every_modified_workflow(self):
        scope = json.loads(MANIFEST.read_text(encoding="utf-8"))
        paths = [
            p for p in scope["allowed_changed_files"]
            if p.startswith(".github/workflows/")
            and not p.startswith(".github/workflows/m453-")
        ]
        self.assertGreaterEqual(len(paths), 40)
        for path in paths:
            with self.subTest(workflow=path):
                raw = (ROOT / path).read_text(encoding="utf-8")
                slug = Path(path).stem
                expected_group = (
                    "group: waffra-pr-" + slug
                    + "-${{ github.event.pull_request.number || github.run_id }}"
                )
                self.assertIn(expected_group, raw)
                self.assertIn(
                    "cancel-in-progress: ${{ github.event_name == 'pull_request' }}",
                    raw,
                )
                self.assertEqual(
                    len(re.findall(r"^concurrency:\s*$", raw, re.MULTILINE)), 1
                )
                self.assertLess(
                    raw.index("\nconcurrency:\n"), raw.index("\njobs:\n")
                )

    def test_cleanup_remains_trusted_and_scoped(self):
        raw = (ROOT / ".github/workflows/m453-superseded-pr-cleanup.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn("pull_request_target:", raw)
        self.assertIn("actions: write", raw)
        self.assertIn("dry_run:", raw)
        self.assertNotIn("actions/checkout", raw)
        self.assertIn("pr.head?.repo?.full_name !== repository", raw)
        self.assertIn("run.head_sha === latest", raw)
        self.assertIn("run.event !== 'pull_request'", raw)
        self.assertIn("run.id === context.runId", raw)
        self.assertIn("linked.number === pr.number", raw)
        self.assertIn("run.head_branch !== branch", raw)
        self.assertIn("cancelWorkflowRun", raw)
        self.assertIn("event === 'workflow_dispatch' && inputs.dry_run !== 'false'", raw)


if __name__ == "__main__":
    unittest.main()
