"""M412: conservative incremental decisions preserve all critical safety checks."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/qa/m412_pr_changed_impact.py"
spec = importlib.util.spec_from_file_location("m412_impact", SCRIPT)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
BEFORE = "a" * 40
AFTER = "b" * 40
EVENT = {
    "action": "synchronize", "before": BEFORE, "after": AFTER,
    "pull_request": {"head": {"sha": AFTER}},
}
PATTERNS = ["lib/main.dart", "lib/waffra_footer.dart", "test/m274_*",
            ".github/workflows/m274-production-ui-golden.yml"]


class IncrementalImpactTests(unittest.TestCase):
    def decide(self, event=EVENT, changed=None, before=BEFORE,
               after=AFTER, ancestor=True, patterns=PATTERNS):
        return m.decide(event, patterns, before, after,
                        changed if changed is not None else ["test/firebase/package.json"],
                        ancestor)

    def test_firebase_only_does_not_rebuild_android_ui(self):
        self.assertFalse(self.decide()[0])

    def test_app_ui_or_exact_workflow_changes_always_run(self):
        self.assertTrue(self.decide(changed=["lib/main.dart"])[0])
        self.assertTrue(self.decide(
            changed=[".github/workflows/m274-production-ui-golden.yml"])[0])

    def test_gating_script_changes_force_workflow_tests(self):
        self.assertTrue(self.decide(changed=[
            "scripts/qa/m412_pr_changed_impact.py"])[0])

    def test_new_or_reopened_pr_runs_full_workflow(self):
        self.assertTrue(self.decide(event={"action": "opened"})[0])

    def test_no_prior_sha_never_skips(self):
        self.assertTrue(self.decide(before="")[0])
        self.assertTrue(self.decide(after="invalid")[0])

    def test_non_fast_forward_or_unknown_diff_never_skips(self):
        self.assertTrue(self.decide(ancestor=False)[0])
        self.assertTrue(m.decide(EVENT, PATTERNS, BEFORE, AFTER, None, True)[0])
        self.assertTrue(m.decide(EVENT, PATTERNS, BEFORE, AFTER, [], True)[0])

    def test_mismatched_event_sha_never_skips(self):
        self.assertTrue(self.decide(event={
            "action": "synchronize",
            "pull_request": {"head": {"sha": "c" * 40}}})[0])

    def test_no_paths_never_skips(self):
        self.assertTrue(self.decide(patterns=[])[0])

    def test_file_patterns_use_whitelist_not_ignore(self):
        self.assertTrue(m.relevant(["lib/waffra_footer.dart"],
                                   ["lib/**", "!lib/waffra_footer.dart"]))

    def test_uses_current_workflow_pr_path_list(self):
        text = (ROOT / ".github/workflows/m274-production-ui-golden.yml").read_text()
        self.assertIn("lib/main.dart", m.workflow_paths(text))
        self.assertIn("test/m274_responsive_ui_journeys_test.dart",
                      m.workflow_paths(text))

    def test_core_main_release_checks_are_unmodified(self):
        release = (ROOT / ".github/workflows/android.yml").read_text()
        self.assertIn("needs: [verify-all-tests, verify-same-sha-checks]", release)
        self.assertIn("flutter test --reporter expanded", release)


if __name__ == "__main__":
    unittest.main()
