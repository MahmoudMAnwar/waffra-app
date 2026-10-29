"""Prove the M279 source gate detects dangerous regressions, not merely markers."""
import importlib.util
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
module_path = HERE / "m279_app_security_gate.py"
spec = importlib.util.spec_from_file_location("m279_gate", module_path)
gate = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(gate)


class SecurityGateMutationTests(unittest.TestCase):
    def test_checked_in_security_boundaries_have_not_regressed(self):
        result = gate.audit_repo(gate.ROOT)
        self.assertEqual(result["errors"], [], msg="; ".join(result["errors"]))
        self.assertGreaterEqual(len(result["checked"]), 8)

    def test_reject_wildcard_public_firestore_read_and_write(self):
        rules = (gate.ROOT / "firestore.rules").read_text()
        modified = rules.replace(
            "allow read, write: if false;",
            "allow read, write: if true;",
        )
        self.assertIn(
            "firestore_public_or_any_signed_in_access",
            gate.firestore_errors(modified),
        )

    def test_reject_any_signed_in_user_access_to_all_documents(self):
        rules = (gate.ROOT / "firestore.rules").read_text()
        modified = rules.replace(
            "allow read, write: if false;",
            "allow read, write: if request.auth != null;",
        )
        self.assertIn(
            "firestore_public_or_any_signed_in_access",
            gate.firestore_errors(modified),
        )

    def test_comment_text_cannot_override_actual_firebase_rules(self):
        rules = (gate.ROOT / "firestore.rules").read_text()
        modified = rules.replace(
            "allow read, write: if false;",
            "allow read, write: if true;",
        )
        commented = "// allow read, write: if false;\n" + modified
        self.assertIn(
            "firestore_public_or_any_signed_in_access",
            gate.firestore_errors(commented),
        )

    def test_reject_removed_tombstone_account_revocation(self):
        rules = (gate.ROOT / "firestore.rules").read_text()
        modified = rules.replace(
            "accountDeletionRequests/$(uid)", "deleted_account_guard_removed",
        )
        self.assertIn(
            "firestore_account_deletion_tombstone_missing",
            gate.firestore_errors(modified),
        )

    def test_reject_removed_ciphertext_allowlist(self):
        rules = (gate.ROOT / "firestore.rules").read_text()
        modified = rules.replace(
            "data.keys().hasOnly(", "data.keys().hasAny(",
        )
        self.assertTrue(any(
            "firestore_envelope_missing" in item
            for item in gate.firestore_errors(modified)
        ))

    def test_reject_high_risk_sms_and_device_permissions(self):
        xml = """<manifest xmlns:android="http://schemas.android.com/apk/res/android">
            <uses-permission android:name="android.permission.READ_SMS"/>
            <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"/>
            </manifest>"""
        self.assertEqual(
            gate.manifest_permission_errors(xml),
            ["prohibited_android_permission_MANAGE_EXTERNAL_STORAGE",
             "prohibited_android_permission_READ_SMS"],
        )

    def test_allow_ordinary_network_permission(self):
        self.assertEqual(gate.manifest_permission_errors(
            '<uses-permission android:name="android.permission.INTERNET"/>'
        ), [])

    def test_prohibition_set_is_not_just_a_read_sms_check(self):
        self.assertIn("REQUEST_INSTALL_PACKAGES",
                      gate.PROHIBITED_ANDROID_PERMISSIONS)
        self.assertIn("QUERY_ALL_PACKAGES",
                      gate.PROHIBITED_ANDROID_PERMISSIONS)


if __name__ == "__main__":
    unittest.main()
