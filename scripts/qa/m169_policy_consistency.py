#!/usr/bin/env python3
"""Read-only AR/EN Play-policy consistency audit. A draft cannot satisfy publication."""
from __future__ import annotations
import json
from pathlib import Path

def inspect(root: Path) -> dict:
    pubspec = (root / "pubspec.yaml").read_text(encoding="utf-8")
    release = root / "docs/release"
    ar = (release / "PRIVACY_POLICY_AR_DRAFT.md").read_text(encoding="utf-8")
    en = (release / "PRIVACY_POLICY_EN_DRAFT.md").read_text(encoding="utf-8")
    data = (release / "PLAY_DATA_SAFETY_REVIEW.md").read_text(encoding="utf-8")
    app = (root / "lib/diagnostics/waffra_crashlytics_opt_in.dart").read_text(encoding="utf-8")
    manifest_build = (root / ".github/workflows/android.yml").read_text(encoding="utf-8")

    checks = {
        "crash_sdk_declared": "firebase_crashlytics:" in pubspec,
        "arabic_crash_sdk_disclosed": "Crashlytics" in ar and "موجودة" in ar,
        "english_crash_sdk_disclosed": "The Firebase Crashlytics SDK **is declared in the app's current dependencies**" in en,
        "data_safety_reflects_sdk": "`firebase_crashlytics`" in data and "is declared" in data,
        "crash_reporter_review_off": "WAFFRA_CRASHLYTICS_READY" in app and "defaultValue: false" in app,
        "native_collection_default_off": 'firebase_crashlytics_collection_enabled' in manifest_build
                                         and 'android:value="false"' in manifest_build,
        "no_bank_link_claims": ("لا يتصل وفرة بالحساب البنكي" in ar
                                and "does not connect to users' bank accounts" in en),
        "manual_sms_only_disclosed": ("ينسخها ويلصقها" in ar and "copy and paste" in en),
        "drafts_not_misrepresented_as_published": ("مسودة غير منشورة" in ar
                                                    and "Draft only" in en),
        "cloud_sync_not_claimed_live": "not be presented as active production" in en
                                       and "قيد التكامل" in ar,
        "account_deletion_not_falsely_complete": "not yet certified" in en
                                                and "لم يُعتمد إنتاجيًا" in ar,
    }
    blockers = [key for key, valid in checks.items() if not valid]
    blockers += [
        "owner_identity_and_contact_unverified",
        "real_public_https_policy_urls_not_published_or_verified",
        "public_and_in_app_account_deletion_not_production_verified",
        "final_signed_aab_sdk_transmission_and_data_flows_unverified",
        "play_console_data_safety_answers_not_submitted_or_checked",
        "country_financial_features_and_android_permissions_not_console_verified",
    ]
    return {
        "milestone": "M169",
        "auditOnly": True,
        "publicationVerified": False,
        "productionApproved": False,
        "checks": checks,
        "sourceConsistencyPassed": all(checks.values()),
        "blockers": blockers,
    }

if __name__ == "__main__":
    root = Path(__file__).resolve().parents[2]
    result = inspect(root)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if not result["sourceConsistencyPassed"]:
        raise SystemExit("M169: disclosure-source inconsistency; review fails closed")
