#!/usr/bin/env python3
"""M177 scoped production-writer boundary review. Never activates encryption."""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess

EXPECTED = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/m177-live-finance-authority.md",
    "lib/main.dart",
    "lib/storage/waffra_home_finance_persistence.dart",
    "lib/storage/waffra_verified_finance_authority.dart",
    "scripts/qa/m177_live_finance_authority_review.py",
    "test/storage/m177_live_finance_authority_integration_test.dart",
}


def git(*args: str) -> str:
    return subprocess.run(["git", *args], text=True, check=True,
                          capture_output=True).stdout.strip()


def audit() -> dict:
    head = git("rev-parse", "HEAD")
    expected = os.environ.get("REVIEW_HEAD_SHA", "").strip()
    if not expected or head != expected:
        raise SystemExit("M177 blocked: SHA not identical to reviewed PR head")
    baseline = git("rev-parse", "refs/remotes/origin/main")
    if git("merge-base", baseline, head) != baseline:
        raise SystemExit("M177 blocked: branch diverged from current main")
    changed = set(filter(None, git("diff", "--name-only", baseline, head).splitlines()))
    if changed != EXPECTED:
        raise SystemExit("M177 blocked: unexpected file scope. missing="
                         + repr(sorted(EXPECTED - changed))
                         + ", extra=" + repr(sorted(changed - EXPECTED)))

    home = Path("lib/main.dart").read_text(encoding="utf-8")
    authority = Path(
        "lib/storage/waffra_verified_finance_authority.dart"
    ).read_text(encoding="utf-8")
    legacy = Path(
        "lib/storage/waffra_home_finance_persistence.dart"
    ).read_text(encoding="utf-8")
    routing = Path(
        "lib/storage/waffra_production_finance_source_guard.dart"
    ).read_text(encoding="utf-8")
    release = Path(
        "lib/storage/waffra_production_cutover_release_gate.dart"
    ).read_text(encoding="utf-8")

    forbidden = [
        "_homeFinancePersistence.withLegacyWriter(",
        "_homeFinancePersistence.loadCustomGoalSuggestions(",
        "_homeFinancePersistence.addCustomGoalSuggestion(",
        "smsHashes.add(pendingHash!)",
    ]
    if any(fragment in home for fragment in forbidden):
        raise SystemExit("M177 blocked: direct legacy writer remains in live Home")
    expected_home = [
        "_financeAuthority.mergeSmsHashes(hashesToSave)",
        "_financeAuthority.setRecurringReminderPreference(enabled)",
        "_financeAuthority.loadCustomGoalSuggestions()",
        "_financeAuthority.addCustomGoalSuggestion(g.name)",
        "_financeAuthority.installCategoryCatalog(",
        "await _persistSmsHashes({pendingHash!});",
        "if(pendingHash!=null&&initial==null){",
        "final applied=await _financeAuthority.commitConfirmedSms(",
        "records:[Map<String,Object?>.from(result.toJson())]",
        "hashes:[pendingHash!]",
        "allowDuplicateHashes:explicitlyApprovedSmsDuplicate",
        "await _financialWriteQueue.drain();",
        "route:WaffraFinanceRoute.backupExport",
        "final authoritativePayload=exportBackup(fromSource:current);",
        "'payload':authoritativePayload,'password':secret.text",
    ]
    if any(fragment not in home for fragment in expected_home):
        raise SystemExit("M177 blocked: source-authority UI routing incomplete")
    expected_authority = [
        "Future<WaffraFinanceAuthorityRead> mergeSmsHashes(",
        "Future<WaffraFinanceAuthorityRead> setRecurringReminderPreference(",
        "Future<List<String>> loadCustomGoalSuggestions()",
        "Future<bool> addCustomGoalSuggestion(String name)",
        "Future<WaffraFinanceAuthorityRead> installCategoryCatalog(",
        "WaffraFinanceRoute.merchantRulesAndSmsHashes",
        "WaffraFinanceRoute.categoryCatalogInstall",
        "await encryptedSession!.addSmsHashes(frozen)",
        "Encrypted custom goal suggestions are not certified.",
        "Encrypted recurring reminder scalar is not certified.",
    ]
    if any(fragment not in authority for fragment in expected_authority):
        raise SystemExit("M177 blocked: unsafe authority fallback or lost guard")
    expected_legacy = [
        "coordinator.withCurrentPreferences((prefs) async {",
        "Future<List<String>> mergeSmsHashes(",
        "Future<void> setRecurringReminderPreference(bool enabled)",
        "Future<void> installCategoryCatalog(",
        "Category catalog changed concurrently; reload.",
    ]
    if any(fragment not in legacy for fragment in expected_legacy):
        raise SystemExit("M177 blocked: legacy operations bypass cross-engine lock")
    if ("all_live_writers_not_yet_routed" not in routing
            or "bool get automaticallyActivateSqlCipher => false;" not in release):
        raise SystemExit("M177 blocked: production cutover auto guard weakened")

    return {
        "milestone": "M177",
        "reviewed_sha": head,
        "base_main_sha": baseline,
        "changed_paths": sorted(changed),
        "live_direct_home_finance_legacy_writers": 0,
        "authority_routed": [
            "bank_sms_hash_merge",
            "recurring_reminder_scalar",
            "custom_goal_suggestions",
            "category_catalog_install_v2_v3",
        ],
        "sqlcipher_hash_merge_bridge_available": True,
        "sqlcipher_custom_goal_and_reminder_not_certified": True,
        "sqlcipher_production_enabled": False,
        "user_data_migration_performed": False,
        "all_24_routes_certified": False,
        "release_authorized": False,
        "status": "M177_LIVE_AUTHORITY_WIRED_RELEASE_NO_GO",
    }


if __name__ == "__main__":
    out = audit()
    path = Path("build/m147-final-review-report.json")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(out, ensure_ascii=True, indent=2) + "\n",
                    encoding="utf-8")
    print(json.dumps(out, ensure_ascii=True, indent=2))
