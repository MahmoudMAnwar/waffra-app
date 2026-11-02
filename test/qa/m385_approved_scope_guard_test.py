"""M385: failure-injection tests for unrequested change protection."""
import importlib.util
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "scripts/qa/m385_approved_change_guard.py"
spec = importlib.util.spec_from_file_location("m385_scope_guard", SCRIPT)
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)

MANIFEST = guard.MANIFEST_PATH


def contract(allowed=None, sections=None):
    if allowed is None:
        allowed = ["lib/main.dart", MANIFEST, "test/new_approval_test.dart"]
    if sections is None:
        sections = {"lib/main.dart": [
            {"start": " Widget oldApproved(){", "end": " Widget unrelated(){"}
        ]}
    return {
        "contract_version": 1,
        "user_requested_changes": ["Keep old screens unchanged, update oldApproved only"],
        "allowed_changed_files": allowed,
        "bounded_sections": sections,
    }


BASE = "BEFORE\n Widget oldApproved(){return const Old();}\n" \
       " Widget unrelated(){return const Preserve();}\n END\n"
HEAD = "BEFORE\n Widget oldApproved(){return const Updated();}\n" \
       " Widget unrelated(){return const Preserve();}\n END\n"


def run(manifest=None, head=HEAD, changed=None, base=BASE):
    manifest = manifest if manifest is not None else contract()
    changed = changed if changed is not None else set(manifest["allowed_changed_files"])
    old = {"lib/main.dart": base}
    new = {"lib/main.dart": head,
           MANIFEST: '{"contract_version":1}',
           "test/new_approval_test.dart": "test: approved new coverage"}
    return guard.audit_scope(manifest, changed, old, new, {"lib/main.dart"})


class NoUnrequestedChangesTest(unittest.TestCase):
    def test_in_scope_feature_fix_can_pass_without_editing_old_data(self):
        self.assertIsNone(run())

    def test_old_feature_edited_without_request_is_blocked(self):
        modified = HEAD.replace("const Preserve()", "const Deleted()")
        with self.assertRaisesRegex(guard.ScopeViolation, "outside"):
            run(head=modified)

    def test_unrelated_file_cannot_be_smuggled_into_pr(self):
        with self.assertRaisesRegex(guard.ScopeViolation, "Unrequested"):
            run(changed=set(contract()["allowed_changed_files"]) | {"lib/budget.dart"})

    def test_changed_existing_app_source_must_have_function_boundary(self):
        manifest = contract(sections={})
        with self.assertRaisesRegex(guard.ScopeViolation, "cannot change wholesale"):
            run(manifest=manifest)

    def test_deleted_existing_app_source_is_not_approved(self):
        manifest = contract()
        with self.assertRaisesRegex(guard.ScopeViolation, "deleted"):
            guard.audit_scope(manifest, set(manifest["allowed_changed_files"]),
                              {"lib/main.dart": BASE},
                              {MANIFEST: "scope", "test/new_approval_test.dart": "test"},
                              {"lib/main.dart"})

    def test_old_function_anchor_removed_fails_closed(self):
        with self.assertRaisesRegex(guard.ScopeViolation, "anchor"):
            run(head=HEAD.replace(" Widget unrelated(){", " Widget hiddenOld(){" ))

    def test_duplicated_scope_anchor_cannot_bypass_audit(self):
        with self.assertRaisesRegex(guard.ScopeViolation, "anchor"):
            run(head=HEAD.replace("BEFORE", " Widget oldApproved(){\nBEFORE"))

    def test_scope_manifest_must_change_with_every_pr(self):
        with self.assertRaisesRegex(guard.ScopeViolation, "manifest"):
            run(changed={"lib/main.dart", "test/new_approval_test.dart"})

    def test_authorization_cannot_be_blank(self):
        manifest = contract()
        manifest["user_requested_changes"] = ["ok"]
        with self.assertRaisesRegex(guard.ScopeViolation, "user-requested"):
            run(manifest=manifest)

    def test_exact_file_set_cannot_silently_drop_a_declared_test(self):
        with self.assertRaisesRegex(guard.ScopeViolation, "missing="):
            run(changed={"lib/main.dart", MANIFEST})

    def test_unapproved_android_workflow_edit_must_have_bounded_scope(self):
        path = ".github/workflows/android.yml"
        manifest = contract(
            allowed=[path, MANIFEST],
            sections={},
        )
        with self.assertRaisesRegex(guard.ScopeViolation, "cannot change wholesale"):
            guard.audit_scope(manifest, {path, MANIFEST},
                              {path: "jobs:\n  build: old"},
                              {path: "jobs:\n  build: new", MANIFEST: "scope"},
                              {path})

    def test_whole_workflow_bypass_in_other_job_is_blocked(self):
        path = ".github/workflows/android.yml"
        manifest = contract(
            allowed=[path, MANIFEST],
            sections={path: [{"start": "  build:\n", "end": None}]},
        )
        original = "  test:\n    run: flutter test\n  build:\n    run: flutter build apk\n"
        modified = original.replace("run: flutter test", "run: true")
        with self.assertRaisesRegex(guard.ScopeViolation, "outside"):
            guard.audit_scope(manifest, {path, MANIFEST},
                              {path: original}, {path: modified, MANIFEST: "scope"}, {path})

    def test_exact_content_outside_scope_must_be_byte_identical(self):
        with self.assertRaisesRegex(guard.ScopeViolation, "outside"):
            run(head=HEAD.replace("BEFORE", "BEFORE-CHANGED"))


if __name__ == "__main__":
    unittest.main()
