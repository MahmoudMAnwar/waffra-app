#!/usr/bin/env python3
"""M188 same-SHA full-finance SQLCipher reset candidate: permanent NO-GO."""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess

FILES = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/m188-sqlcipher-full-finance-reset.md",
    "lib/storage/waffra_encrypted_full_finance_reset.dart",
    "scripts/qa/m188_full_finance_reset_scope_review.py",
    "test/storage/m188_encrypted_full_finance_reset_test.dart",
}

def git(*args: str) -> str:
    return subprocess.run(["git", *args], text=True, capture_output=True,
                          check=True).stdout.strip()

def demand(source: str, values: list[str], label: str) -> None:
    for fragment in values:
        if fragment not in source:
            raise SystemExit(f"M188: missing {label}: {fragment}")

def main() -> None:
    sha = git("rev-parse", "HEAD")
    if not os.environ.get("REVIEW_HEAD_SHA", "").strip() == sha:
        raise SystemExit("M188: exact PR HEAD required for review")
    main_sha = git("rev-parse", "refs/remotes/origin/main")
    if git("merge-base", main_sha, sha) != main_sha:
        raise SystemExit("M188: main moved; rebuild candidate before merge")
    diff = set(filter(None, git("diff", "--name-only",
                                main_sha, sha).splitlines()))
    if diff != FILES:
        raise SystemExit("M188: precisely five reviewed files required: " +
                         repr(sorted(diff ^ FILES)))
    source = Path("lib/storage/waffra_encrypted_full_finance_reset.dart").read_text()
    tests = Path("test/storage/m188_encrypted_full_finance_reset_test.dart").read_text()
    no_go = Path("lib/storage/waffra_production_cutover_release_gate.dart").read_text()
    selector = Path("lib/storage/waffra_production_finance_source_guard.dart").read_text()
    docs = Path("docs/qa/m188-sqlcipher-full-finance-reset.md").read_text()
    demand(source, [
        "class WaffraEncryptedFullFinanceReset",
        "this.experimentalEnabled = false",
        "confirmationPhrase != confirmation",
        "biometricVerified", "externalBackupSaved",
        "WaffraPortableBackupV2.verifyAndPreview(",
        "WaffraRestoredFinanceParity.requireExactFinanceKeys(",
        "WaffraExperimentalWriterGate(",
        "await verifySourceUnderLock();",
        "snapshot.store.transaction(() async {",
        "current.generation != baseline.generation",
        "current.digest != baseline.digest",
        "WaffraEncryptedModuleProjectionGuard.reconcile(",
        "await _requireNoRecoveryHistory(current.values, tables);",
        "await _verifyCurrentTypedLedger(entries);",
        "await _verifyExactLiveReceipts(",
        "SQL hash projection differs from saved finance.",
        "Unattested finance settings block full reset.",
        "Unknown financial SQL table; reset refused.",
        "await snapshot.store.customStatement('DELETE FROM ' + table);",
        "await snapshot.commit(",
        "fullFinanceSnapshot: const <String, Object?>{'entries': '[]'}",
        "Full finance reset left a typed SQL record.",
    ], "atomic encrypted reset contract")
    demand(tests, [
        "atomically deletes funds receipt SMS and modules",
        "incorrect encrypted backup password",
        "needs confirmation biometric and saved backup",
        "stale Widget finance generation",
        "source-marker mismatch",
        "forged typed amount",
        "orphan invoice bytes",
        "typed SMS fingerprints",
        "nonempty recoverable tombstones",
        "unapproved new encrypted financial table",
        "default-off encrypted full reset",
    ], "disposable safety tests")
    demand(docs, [
        "synthetic disposable fixtures",
        "M188_ATOMIC_FULL_FINANCE_RESET_CANDIDATE_NO_GO",
        "booleans in this", "24/24 production financial routes",
    ], "release disclaimer")
    demand(no_go, ["bool get automaticallyActivateSqlCipher => false;"],
           "production source guard")
    demand(selector, ["all_live_writers_not_yet_routed"],
           "live activation evidence")
    report = {
        "milestone": "M188",
        "review_sha": sha,
        "base_main_sha": main_sha,
        "exact_changed_scope": sorted(diff),
        "synthetic_atomic_full_finance_reset_candidate": True,
        "live_biometric_attestation": False,
        "full_live_backup_proven_saved": False,
        "active_home_widget_connected": False,
        "two_physical_android_phones_verified": False,
        "production_activation_authorized": False,
        "status": "M188_ATOMIC_FULL_FINANCE_RESET_CANDIDATE_NO_GO",
    }
    out = Path("build/m147-final-review-report.json")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))

if __name__ == "__main__":
    main()
