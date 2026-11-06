"""M472: the PR pre-merge Python safety gate must mirror main's signed APK.

Source contract only: enforce the existence of the actual unskipped discovery
commands on the exact PR head. CI executes those commands; this is not a
replacement for running any test or proof of on-device acceptance.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
PR_WORKFLOW = ".github/workflows/m174-main-sha-postmerge.yml"
APK_WORKFLOW = ".github/workflows/android.yml"
FULL_QA = "python3 -m unittest discover -s test/qa -p '*_test.py' -v"
SMART_CI = "python3 -m unittest discover -s scripts -p 'test_smart_ci.py' -v"


def contents(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def step(source: str, name: str) -> str:
    anchor = "      - name: " + name + "\n"
    if source.count(anchor) != 1:
        raise AssertionError(f"Missing or duplicate mandatory CI step: {name}")
    start = source.index(anchor)
    end = source.find("\n      - name: ", start + len(anchor))
    return source[start:] if end == -1 else source[start:end]


class M472PremergePythonParityTest(unittest.TestCase):
    def test_m174_runs_for_every_main_pr_at_exact_head(self):
        text = contents(PR_WORKFLOW)
        self.assertIn("  pull_request:\n    branches:\n      - main", text)
        self.assertIn("  push:\n    branches:\n      - main", text)
        self.assertIn("ref: ${{ github.event.pull_request.head.sha || github.sha }}", text)
        self.assertIn('test "$(git rev-parse HEAD)" = "$EXPECTED_SHA"', text)
        # This job is not branch-filtered to a single feature and cannot
        # silently drop the Python gate when source changes are code-only.
        self.assertNotIn("    paths:", text.split("permissions:")[0])

    def test_every_signed_apk_python_check_is_run_before_pr_merge(self):
        pr = contents(PR_WORKFLOW)
        apk = contents(APK_WORKFLOW)
        for name, command in (
            ("Run incremental-CI safety policy tests", SMART_CI),
            ("Run every Python QA test including future test files", FULL_QA),
        ):
            for source in (pr, apk):
                block = step(source, name)
                self.assertIn("run: " + command, block)
                self.assertNotIn("continue-on-error:", block)
                self.assertNotIn("\n        if:", block)
            self.assertLess(
                pr.index("      - name: " + name),
                pr.index("      - name: Generate non-sensitive NO-GO evidence for exact SHA"),
            )

    def test_python_gate_runs_after_m385_scope_review(self):
        pr = contents(PR_WORKFLOW)
        self.assertLess(
            pr.index("      - name: Enforce declared file and function edit scope versus original main"),
            pr.index("      - name: Run every Python QA test including future test files"),
        )


if __name__ == "__main__":
    unittest.main()
