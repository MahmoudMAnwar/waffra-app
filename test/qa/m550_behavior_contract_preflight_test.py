"""M550 source-level preflight regressions; tests MUST NOT be skipped."""
import importlib.util
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "m550_behavior_contract_preflight",
    ROOT / "scripts/qa/m550_behavior_contract_preflight.py",
)
assert SPEC and SPEC.loader
guard = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(guard)


class BehaviorContractPreflightTests(unittest.TestCase):
    def test_catches_old_m417_like_positive_python_string(self):
        sample = '''
class Contract:
 def test_old(self):
  queue=self.read("native/WaffraAutoSmsStore.kt")
  self.assertIn("qualifies(sender, body)", queue)
  self.assertNotIn("commitConfirmedSms", queue)
'''
        old = "fun offer() { if (!qualifies(sender, body)) return false }"
        new = "fun offer() { if (!reviewEligible(sender, body)) return false }"
        stale, count = guard.detect_stale(
            {"test/qa/legacy_test.py": sample},
            {"native/WaffraAutoSmsStore.kt": old},
            {"native/WaffraAutoSmsStore.kt": new},
            {"native/WaffraAutoSmsStore.kt"},
        )
        self.assertEqual(count, 1)
        self.assertEqual(len(stale), 1)
        self.assertIn("qualifies(sender, body)", stale[0]["old_expectation"])

    def test_unchanged_positive_and_negative_checks_are_not_weakened(self):
        sample = '''
class Contract:
 def test_guard(self):
  queue=self.read("native/WaffraAutoSmsStore.kt")
  self.assertIn("isCommittedLocked", queue)
  self.assertNotIn("commitConfirmedSms", queue)
'''
        stale, checked = guard.detect_stale(
            {"test/qa/guard_test.py": sample},
            {"native/WaffraAutoSmsStore.kt": "isCommittedLocked"},
            {"native/WaffraAutoSmsStore.kt": "isCommittedLocked"},
            {"native/WaffraAutoSmsStore.kt"},
        )
        self.assertEqual(checked, 1)
        self.assertEqual(stale, [])

    def test_catches_old_dart_expectation_and_source_split_boundary(self):
        sample = """
final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
expect(native,contains('qualifies(sender, body)'));
native.split('old sender grouping');
"""
        old = "qualifies(sender, body)\nold sender grouping"
        new = "reviewEligible(sender, body)\nlinear grouping"
        stale, checked = guard.detect_stale(
            {"test/m550_contract_test.dart": sample},
            {"native/WaffraAutoSmsStore.kt": old},
            {"native/WaffraAutoSmsStore.kt": new},
            {"native/WaffraAutoSmsStore.kt"},
        )
        self.assertEqual(checked, 2)
        self.assertEqual(len(stale), 2)


    def test_m934_rejects_raw_main_reader_for_relocated_widget_guard(self):
        sample = """
void main(){
 test('widget',(){
  final main=File('lib/main.dart').readAsStringSync();
  expect(main,contains(' Future<void> _refreshWidget()async{'));
  final start=main.indexOf(' void _receiveWidgetAction(){');
 });
}
"""
        stale = guard.detect_unmigrated_home_readers(
            {"test/widget.dart": sample},
            "part 'waffra_home_widget_balance.part.dart';",
            {"waffra_home_widget_balance.part.dart":
             " Future<void> _refreshWidget()async{\n void _receiveWidgetAction(){"},
        )
        self.assertEqual(len(stale), 2)
        self.assertEqual({x["kind"].split(" (")[0] for x in stale},
                         {"expect contains", "source indexOf anchor"})

    def test_m934_reconstructed_home_and_negative_security_assertions_remain_valid(self):
        sample = """
void main(){
 test('safe',(){
  final main=readWaffraMainSourceForContracts();
  expect(main,contains(' Future<void> _refreshWidget()async{'));
 });
 test('raw is deliberately missing moved implementation',(){
  final main=File('lib/main.dart').readAsStringSync();
  expect(main,isNot(contains(' Future<void> _refreshWidget()async{')));
  expect(main,contains("part 'waffra_home_widget_balance.part.dart';"));
 });
}
"""
        self.assertEqual(guard.detect_unmigrated_home_readers(
            {"test/safe.dart": sample},
            "part 'waffra_home_widget_balance.part.dart';",
            {"waffra_home_widget_balance.part.dart":
             " Future<void> _refreshWidget()async{",
            }), [])

    def test_catches_obsolete_inline_workflow_source_assertions(self):
        sample = """
run: |
  from pathlib import Path
  native=Path('native/WaffraAutoSmsStore.kt').read_text()
  assert 'old eligibility gate' in native
"""
        stale, checked = guard.detect_stale(
            {".github/workflows/old.yml": sample},
            {"native/WaffraAutoSmsStore.kt": "old eligibility gate"},
            {"native/WaffraAutoSmsStore.kt": "reviewEligible"},
            {"native/WaffraAutoSmsStore.kt"},
        )
        self.assertEqual(checked, 1)
        self.assertEqual(len(stale), 1)

    def test_baseline_already_missing_literal_is_not_blame_on_new_pr(self):
        sample = '''
class Contract:
 def test_bad_from_main(self):
  src=self.read("native/WaffraAutoSmsStore.kt")
  self.assertIn("never existed",src)
'''
        stale, checked = guard.detect_stale(
            {"test/qa/old_test.py": sample},
            {"native/WaffraAutoSmsStore.kt": "baseline"},
            {"native/WaffraAutoSmsStore.kt": "new baseline"},
            {"native/WaffraAutoSmsStore.kt"},
        )
        self.assertEqual(checked, 1)
        self.assertFalse(stale)

    def test_behavior_manifest_covers_every_changed_production_file(self):
        review = {
            "schema_version": 1,
            "workflow_review_policy": "scan-all-registered-workflows",
            "contracts": [{
                "id": "M550-DESIGN",
                "issue": "M550 issue #492",
                "previous_behavior": "Old tests required old native conditions",
                "approved_behavior": "Review every active job before merging code",
                "source_paths": ["native/WaffraAutoSmsStore.kt"],
                "test_paths": ["test/qa/m550_behavior_contract_preflight_test.py"],
                "safety_invariants": ["No financial security tests are dropped."],
            }],
        }
        available = {
            "native/WaffraAutoSmsStore.kt",
            "test/qa/m550_behavior_contract_preflight_test.py",
            "lib/main.dart",
        }
        changed = {
            "docs/qa/behavior_contract_review.json",
            "native/WaffraAutoSmsStore.kt",
            "lib/main.dart",
        }
        with self.assertRaisesRegex(guard.ContractError, "lib/main.dart"):
            guard.validate_review(review, changed, available)
        review["contracts"][0]["source_paths"].append("lib/main.dart")
        result = guard.validate_review(review, changed, available)
        self.assertEqual(result, ["M550-DESIGN"])
        changed.remove("docs/qa/behavior_contract_review.json")
        with self.assertRaisesRegex(guard.ContractError, "requires updated"):
            guard.validate_review(review, changed, available)

    def test_entire_repository_workflow_inventory_is_dynamic(self):
        inventory = guard.inventory()
        self.assertGreaterEqual(inventory["workflows"], 50)
        self.assertGreater(inventory["dart_tests"], 100)
        self.assertGreater(inventory["python_qa_tests"], 20)
        self.assertGreaterEqual(len(inventory["jobs"]), inventory["workflows"] - 5)
        self.assertTrue(any(
            x["workflow"].endswith("m147-final-main-review-gate.yml")
            for x in inventory["jobs"]
        ))
        self.assertTrue(any(
            x["workflow"].endswith("finance-full-regression.yml") and
            any("flutter test test/" in cmd for cmd in x["test_commands"])
            for x in inventory["jobs"]
        ))

    def test_m550_is_in_existing_and_new_exact_sha_pr_gates(self):
        original = (ROOT / ".github/workflows/m147-final-main-review-gate.yml"
                    ).read_text()
        dedicated = (ROOT / ".github/workflows/m550-behavior-contract-preflight.yml"
                     ).read_text()
        self.assertIn("m550_behavior_contract_preflight.py", original)
        self.assertIn("m550_behavior_contract_preflight.py", dedicated)
        self.assertIn("pull_request:", dedicated)
        self.assertIn("fetch-depth: 0", dedicated)
        self.assertIn("github.event.pull_request.head.sha", dedicated)
        self.assertIn("python3 -m unittest", dedicated)
        self.assertNotIn("continue-on-error: true", dedicated)

    def test_repair_independent_kotlin_compile_error_without_bypassing_checks(self):
        store = (ROOT / "native/WaffraAutoSmsStore.kt").read_text()
        self.assertIn(
            "if (!enabled(context) || sender.isBlank() || sender.trim().length > 100)",
            store,
        )
        self.assertNotIn(
            "if (!enabled(context) || sender.isBlank() || sender.trim().length > 100\n",
            store,
        )


if __name__ == "__main__":
    unittest.main()
