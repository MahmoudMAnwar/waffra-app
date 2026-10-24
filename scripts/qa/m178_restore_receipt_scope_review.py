#!/usr/bin/env python3
"""M178 SHA-pinned read-only attestation code review. Not release approval."""
from __future__ import annotations
import json
import os
import subprocess
from pathlib import Path

EXPECTED = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/m178-restore-receipt-parity.md",
    "lib/storage/waffra_restored_finance_receipt_attestor.dart",
    "lib/storage/waffra_restored_finance_parity.dart",
    "scripts/qa/m178_restore_receipt_scope_review.py",
    "test/storage/m178_restore_receipt_parity_test.dart",
}

def git(*args: str) -> str:
    return subprocess.run(["git", *args], check=True, capture_output=True,
                          text=True).stdout.strip()

def main() -> None:
    head = git("rev-parse", "HEAD")
    required = os.environ.get("REVIEW_HEAD_SHA", "").strip()
    if not required or head != required:
        raise SystemExit("M178: reviewed SHA mismatch")
    baseline = git("rev-parse", "refs/remotes/origin/main")
    if git("merge-base", baseline, head) != baseline:
        raise SystemExit("M178: main advanced or branch diverged")
    files = set(filter(None, git("diff", "--name-only", baseline, head).splitlines()))
    if files != EXPECTED:
        raise SystemExit("M178: changed file scope mismatch "
                         + repr(sorted(files ^ EXPECTED)))
    attestor = Path("lib/storage/waffra_restored_finance_receipt_attestor.dart").read_text()
    parity = Path("lib/storage/waffra_restored_finance_parity.dart").read_text()
    test = Path("test/storage/m178_restore_receipt_parity_test.dart").read_text()
    release = Path("lib/storage/waffra_production_cutover_release_gate.dart").read_text()
    required_attestation = [
        "WaffraRestoredFinanceParity.requireExactTransactionFields(",
        "WaffraRestoredFinanceParity.requireExactFinanceKeys(",
        "sha256.convert(exact.bytes) != sha256.convert(receipts[i].bytes)",
        "actual.generation != reported.encryptedGeneration",
    ]
    if any(needle not in attestor for needle in required_attestation):
        raise SystemExit("M178: restore attestation incomplete")
    if ("expected.containsAll(actual)" not in parity or
        "newKeys.containsAll(oldKeys)" not in parity or
        "unexpectedArchive" not in parity):
        raise SystemExit("M178: parity fail-closed controls missing")
    if "rejects injected, missing" not in test or "refuses missing, extra and unsupported restore keys" not in test:
        raise SystemExit("M178: negative tests missing")
    if "bool get automaticallyActivateSqlCipher => false;" not in release:
        raise SystemExit("M178: production cutover automatic guard missing")
    output = {
        "milestone": "M178", "reviewed_sha": head,
        "main_base_sha": baseline, "files": sorted(files),
        "restore_parity_code_wired": True, "tested_on_two_real_phones": False,
        "sqlcipher_production_active": False, "all_24_routes_proven": False,
        "status": "RESTORE_RECEIPT_ATTESTATION_STAGED_NO_GO",
    }
    path = Path("build/m147-final-review-report.json")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(output, indent=2) + "\n")
    print(json.dumps(output))

if __name__ == "__main__":
    main()
