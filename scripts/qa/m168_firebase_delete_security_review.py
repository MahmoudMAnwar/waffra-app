#!/usr/bin/env python3
"""Fail-closed M168 source audit. Never deploys Firebase rules or deletes accounts."""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
rules = (root / "firestore.rules").read_text()
client = (root / "lib/waffra_account_deletion.dart").read_text()
tests = (root / "test/firebase/firestore.rules.test.mjs").read_text()
checks = {
    "same_uid_only": "request.auth.uid == uid" in rules,
    "deletion_tombstone_checked": "accountDeletionRequests/$(uid)" in rules,
    "no_recursive_public_firestore_access": "match /{document=**}" in rules and "allow read, write: if false;" in rules,
    "no_parent_delete_without_recursive_backend": "allow delete: if false;" in rules,
    "delete_feature_is_default_off": "WAFFRA_ACCOUNT_DELETE_READY" in client and "defaultValue: false" in client,
    "backend_owns_cloud_delete": ".httpsCallable('deleteWaffraAccount')" in client,
    "reauth_required_before_deletion": "reauthenticateCurrentGoogleUser" in client,
    "no_unverified_success_message": "Cloud account deletion was not confirmed." in client,
    "stale_device_emulator_assertions": "M168 deletion tombstone denies old owner" in tests,
}
for name, ok in checks.items():
    print(f"{'PASS' if ok else 'BLOCK'}: {name}")
if not all(checks.values()):
    raise SystemExit("M168: source security guard incomplete")
print("M168 static source gate passed. Firebase emulator and deployed service are separate gates.")
