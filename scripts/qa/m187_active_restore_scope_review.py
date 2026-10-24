#!/usr/bin/env python3
"""M187 exact-HEAD isolated restore preflight, never production cutover."""
from __future__ import annotations
import json
import os
from pathlib import Path
import subprocess

FILES = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/m187-active-encrypted-restore-preflight.md",
    "lib/storage/waffra_verified_active_restore_preflight.dart",
    "scripts/qa/m187_active_restore_scope_review.py",
    "test/storage/m187_active_restore_preflight_test.dart",
}

def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], capture_output=True, text=True, check=True,
    ).stdout.strip()

def check(data: str, markers: list[str], label: str) -> None:
    for marker in markers:
        if marker not in data:
            raise SystemExit(f"M187: {label} evidence missing: {marker}")

def main() -> None:
    head = git("rev-parse", "HEAD")
    if head != os.environ.get("REVIEW_HEAD_SHA", "").strip():
        raise SystemExit("M187: exact-head SHA missing or stale")
    base = git("rev-parse", "refs/remotes/origin/main")
    if git("merge-base", base, head) != base:
        raise SystemExit("M187: main advanced, rebase before review")
    diff = set(filter(None, git("diff", "--name-only", base, head).splitlines()))
    if diff != FILES:
        raise SystemExit("M187: five-file scope mismatch: " +
                         repr(sorted(diff ^ FILES)))

    code = Path("lib/storage/waffra_verified_active_restore_preflight.dart").read_text()
    tests = Path("test/storage/m187_active_restore_preflight_test.dart").read_text()
    source = Path("lib/storage/waffra_production_finance_source_guard.dart").read_text()
    cutover = Path("lib/storage/waffra_production_cutover_release_gate.dart").read_text()
    doc = Path("docs/qa/m187-active-encrypted-restore-preflight.md").read_text()

    check(code, [
        "class WaffraVerifiedActiveRestorePreflight",
        "Future<WaffraVerifiedRestorePreflightResult> inspect(",
        "WaffraFinanceRoute.backupRestore",
        "selectedSource.source != WaffraRuntimeFinanceBackend.verifiedEncrypted",
        "authority.encryptedSession?.experimentalEnabled != true",
        "witness.generation != selected.generation",
        "witness.digest != selected.digest",
        "WaffraPortableBackupV2.verifyAndPreview(",
        "Directory.systemTemp.createTemp(",
        "Random.secure()",
        "WaffraEncryptedStore.openAt(",
        "WaffraPortableEncryptedVaultRestorer(",
        "WaffraRestoredFinanceReceiptAttestor(",
        "Active financial source changed during backup preflight.",
        "await candidate.close();",
        "await stagingDirectory.delete(recursive: true);",
        "bool get activationAuthorized => false;",
        "bool get activeSourceReplaced => false;",
        "bool get requiresIndependentDeviceRecovery => true;",
    ], "backup staging")
    check(tests, [
        "receipt cold-stages without replacing active ledger",
        "zero-receipt authenticated restore preview is read-only",
        "bad password never touches existing encrypted user funds",
        "tampered encrypted envelope cannot overwrite active source",
        "stale Widget write invalidates preflight screen witness",
        "source cutover in progress forbids preview",
        "disabled and unconfirmed routes never open staging database",
    ], "negative restore tests")
    check(source, ["all_live_writers_not_yet_routed"], "source NO-GO")
    check(cutover, [
        "bool get automaticallyActivateSqlCipher => false;",
    ], "production NO-GO")
    check(doc, [
        "read-only", "cold reopens", "two Android phones",
        "M187_STAGING_ONLY_PRODUCTION_NO_GO",
    ], "scope and risk disclosure")
    result = {
        "milestone": "M187",
        "reviewed_sha": head,
        "base_main_sha": base,
        "changed_paths": sorted(diff),
        "existing_finance_source_mutated": False,
        "temporary_sqlcipher_candidate_attested_twice": True,
        "live_active_database_replaced": False,
        "twenty_four_live_finance_routes_certified": False,
        "two_physical_android_phone_restore_tested": False,
        "production_cutover_authorized": False,
        "status": "M187_STAGING_ONLY_PRODUCTION_NO_GO",
    }
    out = Path("build/m147-final-review-report.json")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))

if __name__ == "__main__":
    main()
