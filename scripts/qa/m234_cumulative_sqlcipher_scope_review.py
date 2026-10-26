#!/usr/bin/env python3
"""M234 exact-SHA, cumulative SQLCipher QA-only review; no live cutover."""
from __future__ import annotations

import json
import os
import re
from pathlib import Path
import subprocess

BASE = "8a460fa3d537ee7e8343b01e49d794140e66652a"
EXPECTED = [
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/m228-24-route-source-preflight.md",
    "docs/qa/m230-stage1-consolidation.md",
    "docs/qa/m231-original-sms-recovery-parity.md",
    "docs/qa/m232-original-sms-disposable-restore.md",
    "docs/qa/m233-combined-encrypted-finance-sms-recovery.md",
    "docs/qa/m234-cumulative-sqlcipher-bundle-acceptance.md",
    "docs/release/WAFFRA_APPROVED_CHANGES.txt",
    "lib/main.dart",
    "lib/storage/waffra_combined_portable_recovery.dart",
    "lib/storage/waffra_finance_24_route_preflight.dart",
    "lib/storage/waffra_original_sms_disposable_restore_verifier.dart",
    "lib/storage/waffra_original_sms_portable_preflight.dart",
    "lib/storage/waffra_original_sms_recovery_preflight.dart",
    "lib/storage/waffra_production_finance_authority_binding.dart",
    "lib/storage/waffra_verified_pull_refresh_source.dart",
    "scripts/qa/m228_route_readiness_scope_review.py",
    "scripts/qa/m228_verified_pull_refresh_scope_review.py",
    "scripts/qa/m230_combined_stage1_refresh_review.py",
    "scripts/qa/m234_cumulative_sqlcipher_scope_review.py",
    "test/m224_verified_pull_refresh_dialog_test.dart",
    "test/storage/m228_24_route_preflight_test.dart",
    "test/storage/m228_verified_pull_refresh_source_test.dart",
    "test/storage/m231_original_sms_recovery_preflight_test.dart",
    "test/storage/m232_original_sms_disposable_restore_verifier_test.dart",
    "test/storage/m233_combined_portable_recovery_test.dart"
]

def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True).strip()

def require(value: bool, error: str) -> None:
    if not value:
        raise SystemExit("M234 REVIEW BLOCKED: " + error)

def contains(path: str, *tokens: str) -> None:
    content = Path(path).read_text(encoding="utf-8")
    for token in tokens:
        require(token in content, path + ": missing " + token)

def main() -> None:
    head = git("rev-parse", "HEAD")
    base = git("rev-parse", "refs/remotes/origin/main")
    require(head == os.environ.get("REVIEW_HEAD_SHA"), "head SHA changed")
    require(base == BASE, "main has changed; regenerate audit")
    require(git("merge-base", head, base) == base,
            "not based on exact approved main")
    commits = git("rev-list", "--reverse", BASE + ".." + head).splitlines()
    require(10 <= len(commits) <= 30, "unexpected candidate ancestry")
    allowed = set(EXPECTED)
    for sha in commits:
        parents = git("rev-list", "--parents", "-n", "1", sha).split()
        require(len(parents) == 2, "unreviewed merge commit")
        files = set(filter(None, git("diff-tree", "--no-commit-id",
                                     "--name-only", "-r", sha).splitlines()))
        require(bool(files) and files <= allowed, "unreviewed commit changes")
    changed = set(filter(None, git("diff", "--name-only",
                                   BASE, head).splitlines()))
    require(changed == allowed, "cumulative reviewed file list mismatch: " +
            repr(sorted(changed ^ allowed)))

    routing = Path("lib/storage/waffra_production_finance_routing_gate.dart"
                   ).read_text(encoding="utf-8")
    found = re.search(r"enum WaffraFinanceRoute\s*\{([^}]*)\}", routing)
    require(found is not None, "finance route enum missing")
    routes = [v.strip().rstrip(",") for v in found.group(1).splitlines()
              if v.strip() and not v.lstrip().startswith("//")]
    require(len(routes) == len(set(routes)) == 24,
            "24 distinct finance routes required")
    contains("lib/storage/waffra_finance_24_route_preflight.dart",
             "WaffraFinanceRoute.values", "selector.requireRoute(route)",
             "productionCutoverAuthorized => false")
    contains("lib/storage/waffra_production_finance_authority_binding.dart",
             "checkpoint.sourceDigest != evidence.storage.sourceDigest",
             "WaffraFinance24RoutePreflight().inspect(")
    contains("lib/storage/waffra_verified_pull_refresh_source.dart",
             "WaffraRuntimeFinanceBackend.verifiedEncrypted",
             "ledgerRaw: ledger ?? '[]'")
    contains("lib/storage/waffra_original_sms_portable_preflight.dart",
             "WaffraSecureBackup.encryptUserBackup",
             "WaffraSecureBackup.hasValidEncryptedHeader")
    contains("lib/storage/waffra_original_sms_disposable_restore_verifier.dart",
             "Directory.systemTemp.createTemp",
             "directory.delete(recursive: true)")
    contains("lib/storage/waffra_combined_portable_recovery.dart",
             "WaffraPortableEncryptedVaultRestorer",
             "WaffraRestoredFinanceReceiptAttestor",
             "WaffraDisposableOriginalSmsRestoreVerifier",
             "WaffraSecureBackup.encryptUserBackup",
             "folder.delete(recursive: true)")
    contains("lib/storage/waffra_production_cutover_release_gate.dart",
             "bool get automaticallyActivateSqlCipher => false;")
    for name in [
        "test/storage/m228_24_route_preflight_test.dart",
        "test/storage/m228_verified_pull_refresh_source_test.dart",
        "test/storage/m231_original_sms_recovery_preflight_test.dart",
        "test/storage/m232_original_sms_disposable_restore_verifier_test.dart",
        "test/storage/m233_combined_portable_recovery_test.dart",
    ]:
        require(Path(name).is_file(), "missing required negative tests " + name)
    report = {
        "milestone": "M234",
        "base_main_sha": BASE,
        "reviewed_head_sha": head,
        "reviewed_commit_count": len(commits),
        "reviewed_paths": sorted(changed),
        "structural_route_count": len(routes),
        "source_scope_passed": True,
        "encrypted_backup_disposable_parity_source_present": True,
        "real_24_route_execution_certified": False,
        "two_physical_signed_android_devices_attested": False,
        "production_sqlcipher_active": False,
        "account_profile_recovery_certified": False,
        "production_release_authorized": False,
        "status": "CUMULATIVE_QA_ONLY_PRODUCTION_NO_GO",
    }
    dest = Path("build/m147-final-review-report.json")
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n",
                    encoding="utf-8")
    print("M234 PASS: exact cumulative scope, explicit release NO-GO.")

if __name__ == "__main__":
    main()
