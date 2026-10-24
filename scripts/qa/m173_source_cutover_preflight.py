#!/usr/bin/env python3
"""M173: readonly, fail-closed pre-production audit; emits non-PII JSON.

This script DOES NOT inspect user files/accounts, alter Android/Firebase,
deploy code, or turn on SQLCipher. CI success never certifies live deployment.
"""
from __future__ import annotations

import json
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def inspect(root: Path) -> dict:
    routing = (root / "lib/storage/waffra_production_finance_routing_gate.dart").read_text()
    runtime = (root / "lib/storage/waffra_runtime_finance_route_contract.dart").read_text()
    release = (root / "lib/storage/waffra_production_cutover_release_gate.dart").read_text()
    source = (root / "lib/storage/waffra_finance_source_cutover_policy.dart").read_text()
    app = (root / "lib/main.dart").read_text()
    prod_source = (root / "lib/storage/waffra_production_finance_source_guard.dart").read_text()
    public_policy = root / "docs/release/PRIVACY_POLICY_EN_DRAFT.md"

    enum = re.search(r"enum WaffraFinanceRoute\s*\{([^}]+)\}", routing, re.S)
    routes = [
        line.strip().split("//")[0].strip().rstrip(",")
        for line in (enum.group(1).splitlines() if enum else [])
        if line.strip() and not line.strip().startswith("///")
        and not line.strip().startswith("//")
    ]
    route_count = len([r for r in routes if r and re.fullmatch(r"[a-zA-Z][a-zA-Z0-9]*", r)])

    checks = {
        "exactly_24_finance_routes": route_count == 24,
        "source_review_for_every_route": "for (final route in WaffraFinanceRoute.values)" in routing,
        "encrypted_route_requires_two_witnesses": "encryptedSqlWitnessActive" in runtime
            and "externalSourceWitnessActive" in runtime
            and "verifiedKeyRecoveryInDevice" in runtime,
        "missing_source_requires_manual_recovery": "manualRecoveryRequired:" in runtime
            and "throw StateError(" in runtime,
        "cutover_release_never_automatic": "bool get automaticallyActivateSqlCipher => false;" in release,
        "release_requires_signed_device": "signed_android_device_unverified" in release,
        "release_requires_two_devices": "two_physical_devices_restore_unverified" in release,
        "release_requires_account_deletion": "account_deletion_unverified" in release,
        "release_requires_privacy": "privacy_policy_unpublished" in release,
        "release_requires_explicit_human_approval": "human_release_approval_missing" in release,
        "legacy_finance_markers_not_enabled_here": "preferenceActivationKey" in source
            and "recoveryRequired" in source,
        "active_sql_requires_all_live_writers": "all_live_writers_not_yet_routed" in prod_source,
        "system_still_tracks_legacy_vault_guard": "legacy_source_verified" in prod_source,
        "production_privacy_policy_not_published": "Draft only" in public_policy.read_text(),
        "app_has_reduced_motion_and_arabic": "accessibilityFeatures.disableAnimations" in app
            and "Locale('ar','SA')" in app,
    }
    hard_blockers = [
        "signed_final_sha_android_device_test_missing",
        "two_real_device_restore_and_offline_conflict_proof_missing",
        "24_live_finance_routes_sqlcipher_witnesses_not_attested",
        "encrypted_receipts_and_nonempty_legacy_migration_device_proof_missing",
        "public_privacy_policy_and_data_deletion_backend_not_verified",
        "google_play_delivery_signing_and_oauth_unverified",
        "firebase_data_safety_and_crashlytics_final_disclosures_unverified",
        "explicit_human_release_approval_required",
    ]
    if not all(checks.values()):
        hard_blockers.insert(0, "source_security_contract_incomplete")
    return {
        "milestone": "M173",
        "reviewedSha": os.environ.get("GITHUB_SHA", "local"),
        "sourceGatePass": all(checks.values()),
        "financeRouteCount": route_count,
        "sourceChecks": checks,
        "productionSqlCipherActivated": False,
        "userDataMigrationAttempted": False,
        "releaseReady": False,
        "auditOnly": True,
        "hardBlockers": hard_blockers,
    }


if __name__ == "__main__":
    result = inspect(ROOT)
    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    if not result["sourceGatePass"]:
        raise SystemExit("M173 source guard changed; STOP production review")
