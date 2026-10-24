#!/usr/bin/env python3
"""M184 exact-head SQLCipher expired trash purge; production always NO-GO."""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess

FILES = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/m184-expired-transaction-recycle-purge.md",
    "lib/storage/waffra_encrypted_transaction_recycle.dart",
    "scripts/qa/m184_transaction_expiry_scope_review.py",
    "test/storage/m183_encrypted_transaction_recycle_test.dart",
}

def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], capture_output=True, check=True, text=True,
    ).stdout.strip()

def require(source: str, fragments: list[str], context: str) -> None:
    for fragment in fragments:
        if fragment not in source:
            raise SystemExit(f"M184: {context} missing {fragment!r}")

def main() -> None:
    head = git("rev-parse", "HEAD")
    if head != os.environ.get("REVIEW_HEAD_SHA", "").strip():
        raise SystemExit("M184: exact current PR HEAD was not reviewed")
    base = git("rev-parse", "refs/remotes/origin/main")
    if git("merge-base", base, head) != base:
        raise SystemExit("M184: current main is not ancestor of this branch")
    actual = set(filter(None, git(
        "diff", "--name-only", base, head,
    ).splitlines()))
    if actual != FILES:
        raise SystemExit("M184: unexpected changed file scope "
                         + repr(sorted(actual ^ FILES)))
    engine = Path("lib/storage/waffra_encrypted_transaction_recycle.dart").read_text()
    test = Path("test/storage/m183_encrypted_transaction_recycle_test.dart").read_text()
    source = Path("lib/storage/waffra_production_finance_source_guard.dart").read_text()
    cutover = Path("lib/storage/waffra_production_cutover_release_gate.dart").read_text()
    require(engine, [
        "class WaffraPurgeClockProof",
        "class WaffraEncryptedExpiryPurgeResult",
        "Future<WaffraEncryptedExpiryPurgeResult> purgeExpired(",
        "verifyIndependentClockUnderLock",
        "_requireCandidate();",
        "await verifySourceUnderLock();",
        "WaffraExperimentalWriterGate(",
        "snapshot.store.transaction(() async {",
        "await _requireExactTypedLedger(ledger);",
        "await _requireNoOtherArchive(id);",
        "fresh_finance_transaction_recycle_clock",
        "Encrypted expiry clock moved backwards.",
        "Independent expiry clock witnesses disagree.",
        "retention.inMilliseconds",
        "Expired archived financial checksum differs.",
        "Expired encrypted receipts are incomplete.",
        "DELETE FROM $_images WHERE entry_id=?",
        "DELETE FROM $_trash WHERE entry_id=?",
        "after.digest != current.digest",
        "maxBatch < 1 || maxBatch > 2",
    ], "encrypted expiry implementation")
    require(test, [
        "M184 unexpired 30-day transaction",
        "M184 exactly expired transaction",
        "M184 receipt-free expired",
        "M184 divergent independent clock",
        "M184 remembered encrypted expiry watermark",
        "M184 corrupted encrypted invoice",
        "M184 tampered archived financial amount",
        "M184 missing independent clock provider",
        "M184 pending source marker",
        "M184 purge batch bounds",
    ], "synthetic negative tests")
    require(source, ["all_live_writers_not_yet_routed"],
            "legacy source fail-closed")
    require(cutover, [
        "bool get automaticallyActivateSqlCipher => false;",
    ], "SQLCipher production NO-GO")
    doc = Path("docs/qa/m184-expired-transaction-recycle-purge.md").read_text()
    require(doc, [
        "original deletion-time witness",
        "Synthetic Flutter",
        "Production NO-GO",
    ], "release limitations")
    result = {
        "milestone": "M184",
        "head_sha": head,
        "base_main_sha": base,
        "changed_files": sorted(actual),
        "expired_sqlcipher_recycle_candidate": True,
        "trusted_deletion_time_attestor_available": False,
        "verified_independent_os_clock_connected": False,
        "all_24_live_routes_certified": False,
        "production_sqlcipher_activated": False,
        "status": "M184_EXPERIMENTAL_EXPIRY_PURGE_ONLY_NO_GO",
    }
    target = Path("build/m147-final-review-report.json")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))

if __name__ == "__main__":
    main()
