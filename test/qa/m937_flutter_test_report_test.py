"""Hostile JSON protocol and fail-closed test summary checks for M937."""
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / "scripts/qa/m937_flutter_test_report.py"
spec = importlib.util.spec_from_file_location("m937", SCRIPT)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
SHA = "a" * 40


def feed(*events, success=True):
    values = [
        {"type": "start"},
        {"type": "suite", "suite": {"id": 1, "path": "test/synthetic.dart"}},
        *events,
        {"type": "done", "success": success},
    ]
    return io.StringIO("\n".join(json.dumps(event) for event in values) + "\n")


def start(ident, name="synthetic"):
    return {"type": "testStart", "test": {
        "id": ident, "suiteID": 1, "name": name,
        "metadata": {"skip": False},
    }}


def done(ident, result="success", skipped=False, hidden=False):
    return {"type": "testDone", "testID": ident,
            "result": result, "skipped": skipped, "hidden": hidden}


class SummaryTest(unittest.TestCase):
    def test_pass_fail_skip_and_hidden_loader(self):
        data = feed(start(1), done(1, hidden=True),
                    start(2), done(2),
                    start(3), done(3, skipped=True),
                    start(4),
                    {"type": "error", "testID": 4, "error": "Expected 20 got 30"},
                    done(4, "failure"), success=False)
        r = mod.summary(data, SHA)
        self.assertEqual((r["passed"], r["failed"], r["skipped"], r["total"]),
                         (1, 1, 1, 3))
        self.assertFalse(r["passed_gate"])
        self.assertTrue(r["complete"])

    def test_repeat_failures_grouped_without_raw_error(self):
        r = mod.summary(feed(
            start(1, "one"),
            {"type": "error", "testID": 1, "error": "Expected 20 got 30"},
            done(1, "failure"), start(2, "two"),
            {"type": "error", "testID": 2, "error": "Expected 40 got 50"},
            done(2, "failure"), success=False), SHA)
        self.assertEqual(r["failure_group_estimate"], 1)
        self.assertEqual(r["failed"], 2)
        self.assertNotIn("Expected 20", json.dumps(r))

    def test_interleaved_and_skipped_are_not_counted_as_passed(self):
        r = mod.summary(feed(start(1), start(2), done(2, skipped=True),
                             done(1)), SHA)
        self.assertEqual((r["passed"], r["skipped"]), (1, 1))
        self.assertTrue(r["passed_gate"])

    def test_post_completion_error_fails_hidden_loader(self):
        r = mod.summary(feed(start(1), done(1, hidden=True),
                             {"type": "error", "testID": 1,
                              "error": "Late error"}, success=False), SHA)
        self.assertEqual(r["failed"], 1)

    def test_incomplete_stream_is_red(self):
        incomplete = io.StringIO('{"type":"start"}\n')
        self.assertFalse(mod.summary(incomplete, SHA)["passed_gate"])

    def test_duplicate_done_is_red(self):
        r = mod.summary(feed(start(1), done(1), done(1)), SHA)
        self.assertIn("invalid_or_duplicate_completion", r["issues"])

    def test_runner_error_without_test_error_refused(self):
        r = mod.summary(feed(start(1), done(1), success=False), SHA)
        self.assertFalse(r["passed_gate"])
        self.assertIn("runner_failed_without_test_failure", r["issues"])

    def test_invalid_exact_sha_refused(self):
        with self.assertRaises(ValueError):
            mod.summary(feed(start(1), done(1)), "main")

    def test_cli_missing_events_still_produces_failed_evidence(self):
        import subprocess
        import sys
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            out = root / "report.json"
            process = subprocess.run([sys.executable, str(SCRIPT),
                "--source-sha", SHA, "--input", str(root / "missing"),
                "--output", str(out), "--markdown", str(root / "summary.md")],
                capture_output=True, check=False)
            self.assertNotEqual(process.returncode, 0)
            self.assertFalse(json.loads(out.read_text())["passed_gate"])


if __name__ == "__main__":
    unittest.main()
