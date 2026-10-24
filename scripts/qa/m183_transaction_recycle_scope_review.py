#!/usr/bin/env python3
"""M183 exact-head standalone SQLCipher financial/receipt recycle review."""
from __future__ import annotations
import json
import os
from pathlib import Path
import subprocess

EXPECTED = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/m183-transaction-recycle-with-receipts.md",
    "lib/storage/waffra_encrypted_transaction_recycle.dart",
    "scripts/qa/m183_transaction_recycle_scope_review.py",
    "test/storage/m183_encrypted_transaction_recycle_test.dart",
}

def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], check=True, text=True, capture_output=True,
    ).stdout.strip()

def main() -> None:
    head = git("rev-parse", "HEAD")
    approved = os.environ.get("REVIEW_HEAD_SHA", "").strip()
    if not approved or approved != head:
        raise SystemExit("M183: current exact PR head required")
    base = git("rev-parse", "refs/remotes/origin/main")
    if git("merge-base", base, head) != base:
        raise SystemExit("M183: underlying main SHA is not an ancestor")
    paths = set(filter(None, git("diff", "--name-only", base, head).splitlines()))
    if paths != EXPECTED:
        raise SystemExit("M183: unexpected changed scope " +
                         repr(sorted(paths ^ EXPECTED)))
    code = Path(
        "lib/storage/waffra_encrypted_transaction_recycle.dart",
    ).read_text()
    tests = Path("test/storage/m183_encrypted_transaction_recycle_test.dart").read_text()
    source = Path("lib/storage/waffra_production_finance_source_guard.dart").read_text()
    cutover = Path("lib/storage/waffra_production_cutover_release_gate.dart").read_text()
    routes = Path("lib/storage/waffra_production_finance_routing_gate.dart").read_text()
    for key in [
        "class WaffraEncryptedTransactionRecycle {",
        "WaffraExperimentalWriterGate(",
        "await verifySourceUnderLock();",
        "snapshot.store.transaction(() async {",
        "source_sha256 TEXT NOT NULL",
        "sha256.convert(utf8.encode(archiveJson))",
        "await _requireExactTypedLedger(ledger);",
        "await _requireNoOtherArchive(entryId);",
        "Transaction already has pending recovery.",
        "Receipt was replaced since screen confirmation.",
        "DELETE FROM fresh_finance_receipt_blobs",
        "DELETE FROM fresh_finance_entries",
        "INSERT INTO fresh_finance_entries",
        "INSERT INTO fresh_finance_receipt_blobs",
        "Financial transaction changed; reload to delete.",
        "Transaction recovery clock expired or rolled back.",
        "Restored receipt images failed byte parity.",
        "return snapshot.commit(",
        "retention = Duration(days: 30)",
        "experimentalEnabled = false",
    ]:
        if key not in code:
            raise SystemExit("M183: missing atomic safety contract: " + key)
    for scenario in [
        "reversible SQL commit",
        "identical financial fields and receipt bytes",
        "without creating fake bytes",
        "stale Home finance",
        "outdated byte digest",
        "no consent and wrong receipt",
        "expired or rolled-back clock",
        "corrupted archived encrypted receipt",
        "changed archived financial amount",
        "source activation conflict",
        "disabled source rejects",
    ]:
        if scenario not in tests:
            raise SystemExit("M183: missing negative test: " + scenario)
    if "all_live_writers_not_yet_routed" not in source or (
        "bool get automaticallyActivateSqlCipher => false;" not in cutover
    ) or "transactionDeleteAndUndo" not in routes:
        raise SystemExit("M183: production route/cutover guard not present")
    result = {
        "milestone": "M183",
        "head_sha": head,
        "base_main_sha": base,
        "diff": sorted(paths),
        "synthetic_transaction_receipt_undo_candidate_staged": True,
        "production_live_route_connected": False,
        "all_24_live_routes_attested": False,
        "physical_android_restore_tested": False,
        "automatic_sqlcipher_cutover": False,
        "status": "M183_STANDALONE_TRANSACTION_RECYCLE_NO_GO",
    }
    out = Path("build/m147-final-review-report.json")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))

if __name__ == "__main__":
    main()
