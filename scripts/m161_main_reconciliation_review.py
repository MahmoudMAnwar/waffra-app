#!/usr/bin/env python3
"""M161 read-only staged-integration review. This is NOT production authorization."""
from __future__ import annotations

import json
import os
import pathlib
import subprocess

MAIN = "dbd1605d61a8b522e6c0736ca9b1466b563c74aa"
M158 = "c0eef7e2bfb5bb6836750af48d8b499d0ab30e63"
M160 = "b5ef2dc8a377621907384e3fe2004c1ab1610058"
BRANCH = "integration/m160-reconcile-main-m158-release-gate-20261023"

def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True).strip()

def require(ok: bool, message: str) -> None:
    if not ok:
        raise SystemExit("M161 INTEGRATION REVIEW BLOCKED: " + message)

def read(path: str) -> str:
    return pathlib.Path(path).read_text(encoding="utf-8")

def main() -> None:
    actual = git("rev-parse", "HEAD")
    require(actual == os.getenv("REVIEW_HEAD_SHA", ""), "unchecked PR head")
    require(os.getenv("REVIEW_HEAD_REF") == BRANCH, "unexpected integration branch")
    current_main = git("rev-parse", "refs/remotes/origin/main")
    require(current_main == MAIN, "main advanced; reconcile with latest main first")
    for sha in (MAIN, M158, M160):
        subprocess.run(["git", "merge-base", "--is-ancestor", sha, actual],
                       check=True, capture_output=True)
    modified_storage = set(filter(None, git(
        "diff", "--name-only", M158, actual, "--", "lib/storage", "native", "firebase"
    ).splitlines()))
    require(not modified_storage,
            "unreviewed finance/native/Firebase changes: " + repr(sorted(modified_storage)))
    source_config = git("show", "origin/main:firebase/google-services.json")
    require(read("firebase/google-services.json").strip() == source_config.strip(),
            "registered Firebase Android settings changed")
    main_src = read("lib/main.dart")
    widget = read("lib/waffra_widget_capture.part.dart")
    authority = read("lib/storage/waffra_verified_finance_authority.dart")
    bridge = read("lib/storage/waffra_verified_encrypted_finance_bridge.dart")
    gate = read("lib/storage/waffra_production_cutover_release_gate.dart")
    require("WaffraEncryptedFinanceSession(" not in main_src,
            "unreviewed Home production SQLCipher activation")
    require("WaffraEncryptedFinanceSession(" not in widget,
            "unreviewed Widget production SQLCipher activation")
    require("automaticallyActivateSqlCipher => false" in gate,
            "automatic SQLCipher cutover policy altered")
    require("this.experimentalEnabled = false" in bridge
            and "this.encryptedSqlWitnessActive = false" in authority
            and "this.externalSourceWitnessActive = false" in authority
            and "this.verifiedKeyRecoveryInDevice = false" in authority,
            "verified encrypted finance source witness defaults altered")
    require("_financeAuthority.commitConfirmedSms(" in main_src
            and "_financeAuthority.commitConfirmedSms(" in widget,
            "one of the SMS writers bypasses verified finance authority")
    for word in (
        "waffraCanAssignManualCategory(", "selectedParentId",
        "class WaffraDeletedItemsButton", "bool autoAdvance=false",
        "WaffraBackupFiles.saveEncryptedArchive(encrypted)",
    ):
        require(word in main_src, "approved M161 runtime change missing: " + word)
    start = main_src.find("Future<void> backupDialog()")
    end = main_src.find("// System credentials are never saved", start)
    require(start >= 0 and end > start, "backup-dialog review window missing")
    require("Clipboard.setData" not in main_src[start:end],
            "financial backup ciphertext exported to clipboard")
    require("waffraSafeSmsTransactionTitle(" in widget,
            "Widget bank message may be stored as a raw transaction title")
    backup = read("lib/waffra_secure_backup.dart")
    require("Argon2id(" in backup and "version':2" in backup
            and "version':1" in backup,
            "V2 authenticated export or V1 restore compatibility absent")
    for path in (
        "test/m131_backup_boundary_tamper_qa_test.dart",
        "test/m132_backup_corruption_recovery_negative_test.dart",
        "test/m140_backup_utf8_cross_archive_integrity_test.dart",
        "test/m148_english_categories_legacy_backup_uat_test.dart",
        "test/m149_backup_pin_localized_fab_trash_uat_test.dart",
        "test/m150_file_backup_leaf_categories_uat_test.dart",
        "test/m161_manual_category_leaf_routing_test.dart",
        "test/storage/m156_sqlcipher_merchant_atomic_commit_test.dart",
    ):
        require(pathlib.Path(path).is_file(), "missing integration QA: " + path)

    report = {
        "milestone": "M161",
        "integration_head_sha": actual,
        "main_anchor": MAIN,
        "m158_integrated_source": M158,
        "finance_and_native_drift_from_m158": [],
        "registered_firebase_config_preserved": True,
        "production_sqlcipher_cutover_authorized": False,
        "automatic_merge_authorized": False,
        "store_release_authorized": False,
        "status": "REVIEW_SCOPE_ACCEPTED_NOT_DEVICE_OR_RELEASE_SIGNOFF",
        "still_required": [
            "Complete same-SHA Flutter, storage, receipt, backup and Android CI",
            "Signed APK installed on a real Android device with cold restart",
            "Actual backup migration and receipt/widget rollback/restore evidence",
            "Explicit production-source release authorization before cutover",
        ],
    }
    dest = pathlib.Path("build/m147-final-review-report.json")
    dest.parent.mkdir(exist_ok=True, parents=True)
    dest.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))

if __name__ == "__main__":
    main()
