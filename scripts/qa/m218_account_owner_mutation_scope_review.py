#!/usr/bin/env python3
"""M218 exact-head account SQL mutation review, production NO-GO."""
import json
import os
import subprocess
from pathlib import Path

SCOPE = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/m218-owner-bound-encrypted-account-atomic-write.md",
    "docs/release/WAFFRA_APPROVED_CHANGES.txt",
    "lib/storage/waffra_encrypted_account_owner_mutations.dart",
    "scripts/qa/m218_account_owner_mutation_scope_review.py",
    "test/storage/m218_encrypted_account_owner_mutations_test.dart",
}

def git(*args):
    return subprocess.run(
        ["git", *args], text=True, capture_output=True, check=True,
    ).stdout.strip()

def require(ok, reason):
    if not ok:
        raise SystemExit("M218 BLOCKED: " + reason)

def read(path):
    return Path(path).read_text(encoding="utf-8")

def main():
    head = git("rev-parse", "HEAD")
    base = git("rev-parse", "refs/remotes/origin/main")
    require(head == os.environ.get("REVIEW_HEAD_SHA", "").strip(),
            "reviewed SHA does not match checkout")
    require(git("merge-base", base, head) == base,
            "branch does not contain latest main")
    changed = set(filter(None, git(
        "diff", "--name-only", base, head,
    ).splitlines()))
    require(changed == SCOPE, "scope differs from approved six files: " +
            repr(sorted(changed ^ SCOPE)))
    source = read("lib/storage/waffra_encrypted_account_owner_mutations.dart")
    tests = read("test/storage/m218_encrypted_account_owner_mutations_test.dart")
    guide = read("docs/qa/m218-owner-bound-encrypted-account-atomic-write.md")
    notes = read("docs/release/WAFFRA_APPROVED_CHANGES.txt")
    workflow = read(".github/workflows/m147-final-main-review-gate.yml")
    cutover = read("lib/storage/waffra_production_cutover_release_gate.dart")
    app = read("lib/main.dart")

    for marker in (
        "class WaffraEncryptedAccountOwnerMutations",
        "experimentalEnabled = false",
        "if (!experimentalEnabled)",
        "WaffraExperimentalWriterGate(",
        "sourceGuard.inspect()",
        "WaffraProductionFinanceSource.encryptedRoutingRequired",
        "currentAuthenticatedUid",
        "readDeviceOwnerKey",
        "Hmac(sha256, deviceKey)",
        "fresh_account_profile_principal_binding",
        "fresh_finance_cutover_checkpoint",
        "shadow_migrations",
        "fresh_account_profile_stage_marker",
        "approvedProfileKeys",
        "store.transaction(() async",
        "ON CONFLICT(profile_key) DO UPDATE SET",
        "SQLCipher account mutation parity mismatch.",
        "Encrypted account edit has stale source evidence.",
    ):
        require(marker in source, "missing SQL owner/CAS safeguard: " + marker)
    for forbidden in (
        "SharedPreferences", "FirebaseAuth", "print(", "debugPrint(",
        "CREATE TABLE", "prefs.set", "setString('entries'",
    ):
        require(forbidden not in source, "unsafe profile writer marker: " + forbidden)

    expected_tests = (
        "M218 atomic encrypted account update persists reviewed values",
        "M218 atomic encrypted signout preserves registered record",
        "M218 disabled account writer cannot touch an existing vault",
        "M218 account switch cannot overwrite another owner vault",
        "M218 changed OS owner secret cannot overwrite a vault",
        "M218 missing OS owner key refuses account mutation",
        "M218 uncertified or legacy source blocks encrypted mutation",
        "M218 absent principal witness blocks owner enrollment shortcut",
        "M218 stale account baseline fails closed without partial edits",
        "M218 rejected PIN and token fields never enter encrypted profile",
        "M218 malformed profile JSON cannot be committed",
        "M218 missing active cutover checkpoint refuses mutation",
        "M218 changed legacy finance witness refuses account writes",
        "M218 invalid signed-out boolean fails before SQL writes",
    )
    for marker in expected_tests:
        require(marker in tests, "negative regression test missing: " + marker)
    require("M218 SHA-pinned" in workflow and
            "m218_account_owner_mutation_scope_review.py" in workflow,
            "exact-head CI review is not connected")
    require("[28] M218" in notes, "release changes not updated")
    require("production NO-GO" in guide and
            "physical Android" in guide and
            "OS-protected" in guide, "release blockers undocumented")
    require("bool get automaticallyActivateSqlCipher => false;" in cutover,
            "source activation gate was changed")
    require("WaffraEncryptedAccountOwnerMutations" not in app,
            "unapproved user-facing account source switch")
    out = Path("build/m147-final-review-report.json")
    out.parent.mkdir(parents=True, exist_ok=True)
    result = {
        "milestone": "M218",
        "reviewed_head": head,
        "main_at_review": base,
        "paths": sorted(changed),
        "sqlcipher_atomic_account_writer": True,
        "existing_hmac_owner_required": True,
        "live_user_ui_source_switched": False,
        "physical_devices_attested": 0,
        "production": "NO_GO",
    }
    out.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result))

if __name__ == "__main__":
    main()
