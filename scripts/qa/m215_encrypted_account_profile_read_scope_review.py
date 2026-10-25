#!/usr/bin/env python3
"""M215 exact-head read-only encrypted account candidate review (NO-GO)."""

import json
import os
import subprocess
from pathlib import Path

APPROVED = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/m215-verified-encrypted-account-profile-read.md",
    "docs/release/WAFFRA_APPROVED_CHANGES.txt",
    "lib/storage/waffra_verified_encrypted_account_profile_read.dart",
    "scripts/qa/m215_encrypted_account_profile_read_scope_review.py",
    "test/storage/m215_verified_encrypted_account_profile_read_test.dart",
}


def git(*args):
    return subprocess.run(
        ["git", *args], check=True, capture_output=True, text=True
    ).stdout.strip()


def require(condition, message):
    if not condition:
        raise SystemExit("M215 BLOCKED: " + message)


def read(path):
    return Path(path).read_text(encoding="utf-8")


def main():
    head = git("rev-parse", "HEAD")
    base = git("rev-parse", "refs/remotes/origin/main")
    require(head == os.environ.get("REVIEW_HEAD_SHA", "").strip(),
            "not reviewing exact PR head")
    require(git("merge-base", base, head) == base,
            "branch does not contain current main")
    changed = set(filter(None, git(
        "diff", "--name-only", base, head
    ).splitlines()))
    require(changed == APPROVED, "unapproved scope: " +
            repr(sorted(changed ^ APPROVED)))

    reader = read("lib/storage/waffra_verified_encrypted_account_profile_read.dart")
    tests = read("test/storage/m215_verified_encrypted_account_profile_read_test.dart")
    guide = read("docs/qa/m215-verified-encrypted-account-profile-read.md")
    workflow = read(".github/workflows/m147-final-main-review-gate.yml")
    notes = read("docs/release/WAFFRA_APPROVED_CHANGES.txt")
    cutover = read("lib/storage/waffra_production_cutover_release_gate.dart")
    legacy = read("lib/storage/waffra_home_finance_persistence.dart")

    for marker in (
        "class WaffraVerifiedEncryptedAccountProfileRead",
        "if (!experimentalEnabled)",
        "expectedVaultId",
        "expectedSourceSha256",
        "shadow_migrations",
        "fresh_account_profile_stage_marker",
        "fresh_account_profile_staging",
        "store.transaction(() async",
        "approvedProfileKeys",
        "Map<String, String>.unmodifiable(captured)",
        "Encrypted account/finance witness mismatch.",
        "Encrypted account staging is incomplete.",
    ):
        require(marker in reader, "missing source integrity marker: " + marker)
    for forbidden in (
        "SharedPreferences", "FirebaseAuth", "signIn(", "signOut(",
        "sourceGuard.activate", "automaticallyActivateSqlCipher = true",
        "debugPrint(", "print(",
    ):
        require(forbidden not in reader, "unsafe candidate reader: " + forbidden)
    for marker in (
        "M215 candidate read is disabled by default",
        "M215 verified encrypted profile read preserves exact source bytes",
        "M215 missing encrypted profile stage cannot fall back to legacy",
        "M215 wrong vault and changed finance source witness are rejected",
        "M215 marker count mismatch refuses incomplete profile",
        "M215 missing completion witness fails closed",
        "M215 unapproved credential-like account key refuses read",
        "M215 malformed staged person JSON refuses read",
        "M215 empty staged account stays a verified empty account",
        "M215 rejects invalid expected source witness without SQL reads",
    ):
        require(marker in tests, "missing fail-closed test: " + marker)
    require("M215 SHA-pinned" in workflow and
            "m215_encrypted_account_profile_read_scope_review.py" in workflow,
            "CI audit step not installed")
    require("[25] M215" in notes, "release notes not updated")
    require("Production NO-GO" in guide and
            "physical Android" in guide and "principal" in guide,
            "production blockers not documented")
    require("bool get automaticallyActivateSqlCipher => false;" in cutover,
            "SQLCipher auto-activation is not blocked")
    require("WaffraLegacySmsNotesPrivacyGate.rejectConfirmedSmsNotes(copied)" in legacy,
            "bank SMS plaintext fail-closed guard missing")

    report = {
        "milestone": "M215",
        "reviewed_head": head,
        "main_at_review": base,
        "files": sorted(changed),
        "encrypted_candidate_read_only": True,
        "legacy_fallback": False,
        "live_profile_ui_connected": False,
        "auth_principal_bound": False,
        "real_physical_android_devices": 0,
        "production_status": "NO_GO",
    }
    output = Path("build/m147-final-review-report.json")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
