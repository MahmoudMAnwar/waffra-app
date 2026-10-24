#!/usr/bin/env python3
"""Exact-commit QA-only route/receipt/migration scope; never certifies production."""
import json
import os
import subprocess
from pathlib import Path

FILES = {
    ".github/workflows/m147-final-main-review-gate.yml",
    ".github/workflows/m201-sqlcipher-finance-acceptance.yml",
    "docs/qa/m201-24-route-migration-receipt-device-acceptance.md",
    "scripts/qa/m201_finance_acceptance_scope_review.py",
    "test/storage/m201_24_route_no_false_production_proof_test.dart",
}


def git(*args):
    return subprocess.run(
        ["git", *args], capture_output=True, text=True, check=True,
    ).stdout.strip()


def main():
    head = git("rev-parse", "HEAD")
    if head != os.environ.get("REVIEW_HEAD_SHA", "").strip():
        raise SystemExit("M201 BLOCKED: reviewed head SHA changed")
    base = git("rev-parse", "refs/remotes/origin/main")
    if git("merge-base", base, head) != base:
        raise SystemExit("M201 BLOCKED: branch is not based on current main")
    actual = set(filter(None, git("diff", "--name-only", base, head).splitlines()))
    if actual != FILES:
        raise SystemExit("M201 BLOCKED: scope mismatch " +
                         repr(sorted(actual ^ FILES)))

    workflow = Path(".github/workflows/m201-sqlcipher-finance-acceptance.yml").read_text()
    tests = Path("test/storage/m201_24_route_no_false_production_proof_test.dart").read_text()
    guide = Path("docs/qa/m201-24-route-migration-receipt-device-acceptance.md").read_text()
    main = Path("lib/storage/waffra_production_cutover_release_gate.dart").read_text()
    for marker in (
        "m201_24_route_no_false_production_proof_test.dart",
        "live_finance_migration_rehearsal_test.dart",
        "m102_restored_finance_receipt_attestor_test.dart",
        "m183_encrypted_transaction_recycle_test.dart",
        "m188_encrypted_full_finance_reset_test.dart",
        "m187_active_restore_preflight_test.dart",
        "portable_encrypted_vault_restorer_test.dart",
        "physical_phones_attested",
        "source_cutover_approved",
    ):
        if marker not in workflow:
            raise SystemExit("M201 BLOCKED: essential test/evidence missing " + marker)
    for marker in (
        "WaffraFinanceRoute.values.length, 24",
        "for (final absent in WaffraFinanceRoute.values)",
        "manualRecoveryRequired",
        "throwsStateError",
    ):
        if marker not in tests:
            raise SystemExit("M201 BLOCKED: finance-route negative matrix absent " + marker)
    for marker in ("NO-GO", "two physical", "backupRestore", "fullFinanceReset"):
        if marker not in guide:
            raise SystemExit("M201 BLOCKED: hardware/runbook distinction missing " + marker)
    if "bool get automaticallyActivateSqlCipher => false;" not in main:
        raise SystemExit("M201 BLOCKED: automatic activation altered")

    output = Path("build/m147-final-review-report.json")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps({
        "reviewed_head_sha": head,
        "base_sha": base,
        "changed_files": sorted(actual),
        "verified_live_route_operations": 0,
        "physical_device_attestations": 0,
        "production_sqlcipher_activation": False,
        "release_approved": False,
        "status": "EXACT_SHA_FOCUSED_QA_ONLY_NO_GO"
    }, indent=2) + "\n")
    print("M201 exact-SHA scope and production fail-closed contract accepted")


if __name__ == "__main__":
    main()
