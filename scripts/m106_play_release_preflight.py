#!/usr/bin/env python3
"""Pre-production REVIEW report: never assert readiness from documentation alone."""
from __future__ import annotations

import json
import os
from pathlib import Path


def inspect(root: Path) -> dict:
    pubspec = (root / "pubspec.yaml").read_text(encoding="utf-8")
    workflow = (root / ".github/workflows/android.yml").read_text(encoding="utf-8")
    diag = (root / "lib/diagnostics/waffra_private_release_diagnostics.dart").read_text(encoding="utf-8")
    docs = [
        "PRIVACY_POLICY_AR_DRAFT.md",
        "PRIVACY_POLICY_EN_DRAFT.md",
        "PLAY_STORE_LISTING_AR_EN_DRAFT.md",
        "PLAY_DATA_SAFETY_REVIEW.md",
        "PRODUCTION_GO_LIVE_CHECKLIST.md",
    ]
    files_present = all((root / "docs/release" / name).is_file() for name in docs)
    signed_apk = "Configure and validate Waffra release signing" in workflow
    candidate_aab = ("flutter build appbundle" in workflow and
                     "targetSdk = 36" in workflow)
    sdk = "firebase_crashlytics:" in pubspec
    telemetry_default_off = ("this.userConsented = false" in diag and
                             "this.releaseConfigurationVerified = false" in diag)
    blockers = []
    if not files_present:
        blockers.append("privacy_store_document_drafts_missing")
    if not signed_apk:
        blockers.append("release_signature_validation_missing")
    if not candidate_aab:
        blockers.append("android_api36_signed_aab_pipeline_not_verified")
    if not telemetry_default_off:
        blockers.append("privacy_diagnostics_allowlist_not_verified")
    if not sdk:
        blockers.append("crashlytics_sdk_and_native_opt_in_not_integrated")
    # These attestations require independent evidence, never string greps.
    blockers.extend([
        "public_https_privacy_policy_not_published_or_approved",
        "support_and_publisher_identity_unconfirmed",
        "external_and_in_app_account_deletion_unverified",
        "google_play_data_safety_form_unverified",
        "finance_sqlcipher_24_live_routes_unverified",
        "real_two_phone_e2ee_restore_unverified",
        "release_aab_api36_metadata_and_signing_unverified",
        "physical_phone_install_google_signin_unverified",
        "google_play_closed_testing_and_access_unverified",
    ])
    return {
        "releaseReady": not blockers,
        "auditOnly": True,
        "branchSha": os.environ.get("GITHUB_SHA", "local"),
        "hasDraftPolicyFiles": files_present,
        "hasCandidateAabJob": candidate_aab,
        "hasSignedApkJob": signed_apk,
        "hasDefaultOffDiagnosticBoundary": telemetry_default_off,
        "hasCrashlyticsSdk": sdk,
        "productionDataMigration": False,
        "firebaseRulesDeployed": False,
        "blockers": blockers,
    }


if __name__ == "__main__":
    root = Path(__file__).resolve().parent.parent
    report = inspect(root)
    target = os.getenv("WAFFRA_PLAY_AUDIT_PATH")
    if target:
        Path(target).write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps(report, ensure_ascii=False, indent=2))
    # Producing a review report passes CI, *not* the Production approval gate.
