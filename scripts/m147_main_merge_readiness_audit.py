#!/usr/bin/env python3
"""M147/M225 strict main-bound, exact-head source and review-scope audit.

Read-only: NEVER activates finance sources, changes user data, or publishes
releases. Unlike the historical M147-only candidate, this explicitly reviews
the M225 SQLCipher rehearsal changes against the current pinned main.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess

BASE_MAIN = "8172232ef233fc685291e3e60da9eac0ec9afc8c"
ALLOWED = {
    "scripts/m147_main_merge_readiness_audit.py",
    "docs/release/WAFFRA_APPROVED_CHANGES.txt",
    "lib/storage/waffra_restored_finance_receipt_attestor.dart",
    "lib/storage/waffra_production_finance_authority_binding.dart",
    "test/storage/portable_encrypted_vault_restorer_test.dart",
    "test/storage/production_finance_authority_binding_test.dart",
}
FINANCE_GUARDS = (
    "if(applied.originalSmsNotesOmittedOnLegacy)",
    "notes:raw,sourceType:'sms'",
    "WaffraProductionFinanceAuthorityBinding.bind(",
    "WaffraFinanceRoute.dashboardRead",
    "requireIntegrity()",
)
GOLD_GUARDS = (
    "WaffraGoldSpotQuote.fromXausJson",
    "fallbackEndpoint",
    "Gold price or UTC update time missing.",
)
REFRESH_GUARDS = (
    "_refreshFromVerifiedFinance",
    "await _financialWriteQueue.drain();",
    "onRefresh:_refreshFromVerifiedFinance",
    "if(tab>0&&tab<4)",
)

def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True).strip()

def require(ok: bool, message: str) -> None:
    if not ok:
        raise SystemExit("M147/M225 MERGE BLOCKED — " + message)

def main() -> None:
    head = git("rev-parse", "HEAD")
    origin_main = git("rev-parse", "refs/remotes/origin/main")
    require(head == os.environ.get("REVIEW_HEAD_SHA", ""),
            "checked out candidate does not match the event PR head")
    require(origin_main == BASE_MAIN,
            "main advanced: rebuild and rerun exact-main audit")
    require(git("merge-base", BASE_MAIN, head) == BASE_MAIN,
            "candidate must directly descend from pinned main")
    behind, ahead = map(int, git("rev-list", "--left-right", "--count",
                                  f"{BASE_MAIN}...{head}").split())
    require(behind == 0 and 0 < ahead <= 60,
            "unexpected candidate ancestry or commit count")
    changed = set(filter(None,
        git("diff", "--name-only", BASE_MAIN, head).splitlines()))
    require(changed == ALLOWED,
            "changed-file scope mismatch: " + repr(sorted(changed ^ ALLOWED)))
    require(not any(p.startswith(("native/", "firebase/"))
                    for p in changed),
            "Android native and Firebase are out of scope")
    require(not any(p.startswith("lib/storage/") and p not in {
                    "lib/storage/waffra_restored_finance_receipt_attestor.dart",
                    "lib/storage/waffra_production_finance_authority_binding.dart",
                    } for p in changed),
            "M225 may only tighten restore parity and startup source binding")
    require(not any(p.startswith(".github/workflows/") for p in changed),
            "CI workflow files must stay unmodified")
    require(not any(p in changed for p in (
        "pubspec.yaml", "pubspec.lock", "android/app/google-services.json")),
        "production dependencies and credentials cannot be changed")
    main_code = Path("lib/main.dart").read_text()
    gold_code = Path("lib/waffra_gold_market_data.dart").read_text()
    review_code = Path("test/m224_verified_pull_refresh_dialog_test.dart").read_text()
    gold_test = Path("test/m224_verified_gold_fallback_test.dart").read_text()
    sms_code = Path("lib/storage/waffra_encrypted_legacy_sms_reattachment.dart").read_text()
    sms_qa = Path("test/storage/m224_encrypted_legacy_sms_reattachment_test.dart").read_text()
    sms_bulk = Path("test/storage/m224_full_sms_batch_preservation_test.dart").read_text()
    legacy_pdf_reviews = [
        Path(path).read_text() for path in (
            "test/waffra_footer_pdf_navigation_test.dart",
            "test/waffra_m208_bundle_regression_test.dart",
            "test/waffra_oct21_regression_test.dart",
        )
    ]
    require(all("$pdfCurrency" in source or "$pdfCurrencyAr" in source
                or "pdfAmount" in source for source in legacy_pdf_reviews),
            "legacy PDF reviews must check verified selected-currency exports")
    pdf_qa = Path("test/m224_pdf_verified_display_currency_test.dart").read_text()
    emulator_proof = Path("integration_test/m202_home_widget_source_binder_android_test.dart").read_text()
    widget_code = Path("lib/waffra_widget_capture.part.dart").read_text()
    widget_qa = Path("test/waffra_widget_quick_capture_test.dart").read_text()
    authority = Path("lib/storage/waffra_verified_finance_authority.dart").read_text()
    routes = Path("lib/storage/waffra_production_finance_routing_gate.dart").read_text()
    release_gate = Path("lib/storage/waffra_production_cutover_release_gate.dart").read_text()
    notes = Path("docs/release/WAFFRA_APPROVED_CHANGES.txt").read_text()
    require(all(g in main_code for g in FINANCE_GUARDS),
            "legacy SMS privacy/source guard or verified route missing")
    require(all(g in main_code for g in REFRESH_GUARDS),
            "authoritative UI refresh / data protection missing")
    require(all(g in gold_code for g in GOLD_GUARDS),
            "gold provider and strict source-time checks missing")
    require("MockClient" in gold_test and "throwsFormatException" in gold_test
            and "offline" in gold_test,
            "independent gold provider negative QA missing")
    require("if(applied.originalSmsNotesOmittedOnLegacy)" in review_code,
            "guard must be explicitly covered by a regression")
    require(all(s in sms_code for s in (
        "this.experimentalEnabled = false",
        "verifyEncryptedSourceUnderLock();",
        "WaffraExperimentalWriterGate(",
        "snapshot.store.transaction(",
        "snapshot.commit(",
        "SELECT source_json FROM fresh_finance_entries WHERE entry_id=?",
        "bankSmsFingerprint(originalSms) != expectedHash",
    )), "exact encrypted-only SMS recovery authorization, parity or lock missing")
    require(all(k in sms_bulk for k in (
        "all 56 full bank SMS notes survive encrypted batch and cold reopen",
        "replayed 56 SMS hashes cannot create duplicate transactions",
        "synthetic failure in one original-SMS row rolls back whole batch",
        "expect(prefs.getString('entries'),isNull)",
        "expect(found(encryptedBytes,sample),isFalse",
    )), "56-bank-SMS lossless SQLCipher batch regression missing")
    require(all(s in sms_qa for s in (
        "cold-reopens exact", "SQL failure rolls back",
        "wrong parser amount", "disabled-by-default",
    )), "SMS recovery negative / cold reopen QA missing")
    require(all(marker in emulator_proof for marker in (
        "originalWidgetSms",
        "originalHomeSms",
        "widget.authority.commitConfirmedSms(",
        "home.authority.commitConfirmedSms(",
        "expect(recovered.ledgerRaw, finalLedger)",
        "hasBytes(encryptedBytes, utf8.encode(raw))",
        "for (final key in legacy.getKeys())",
        "incorrect-test-only-key",
    )), "real Android binder original SMS cold-reopen and plaintext leak proof missing")
    require("Map<String, Object?>.unmodifiable({...record, 'notes': ''})"
            in authority and
            "originalSmsNotesOmittedOnLegacy" in authority,
            "legacy privacy guard cannot be removed")
    require(all(g in widget_code for g in (
        "await WaffraDisplayCurrency.initialize();",
        "final conceal=hidden||display==null;",
        "currency:WaffraDisplayCurrency.label(_english)",
    )), "standalone widget engine cannot mislabel SAR as selected FX")
    require("widget FX must convert SAR or conceal" in widget_qa
            and "currency:WaffraDisplayCurrency.label(waffraIsEnglish)" in widget_qa,
            "widget FX/hidden fallback regression is missing")
    require("automaticallyActivateSqlCipher => false" in release_gate,
            "production activation would be unsafe")
    # M224 adds no real-device evidence. A complete route enum is an audit
    # inventory, not proof any route is live on production SQLCipher.
    route_lines = routes.split("enum WaffraFinanceRoute {", 1)[1].split("}", 1)[0]
    inventory = [line.split("//")[0].strip().rstrip(",")
                 for line in route_lines.splitlines() if line.strip()]
    require(len(inventory) == 24 and len(set(inventory)) == 24,
            "SQLCipher route audit inventory does not enumerate exactly 24")
    require("verifiedRoutes = const <WaffraFinanceRoute>{}" in routes,
            "unverified routes must not be preapproved")
    pdf_app = main_code.split("Future<void> exportEntriesPdf(", 1)[1]
    require(all(x in pdf_app for x in (
        "final pdfQuote=WaffraDisplayCurrency.active.value",
        "if(!pdfQuote.verified)",
        "final n=pdfAmount(number)",
        "Amount ($pdfCurrency)",
        "المبلغ ($pdfCurrencyAr)",
        "svg:weeklySpendSvg(smartData!.weeklySpend.map(pdfAmount).toList())",
        "svg:pairedBarChartSvg(buckets.map(",
    )), "PDF must verify one selected FX source across all values and plots")
    require("primaryRate" in pdf_qa and "stale FX" in pdf_qa,
            "PDF EGP/FX negative regression missing")
    require("M224" in notes and "SQLCipher" in notes,
            "release notes omit verified scope and SQLCipher NO-GO")
    require("M225" in notes and "SQLCipher" in notes,
            "M225 release notes must preserve encryption and hardware NO-GO")
    attestor = Path(
        "lib/storage/waffra_restored_finance_receipt_attestor.dart"
    ).read_text()
    binding = Path(
        "lib/storage/waffra_production_finance_authority_binding.dart"
    ).read_text()
    attestor_test = Path(
        "test/storage/portable_encrypted_vault_restorer_test.dart"
    ).read_text()
    binding_test = Path(
        "test/storage/production_finance_authority_binding_test.dart"
    ).read_text()
    require(all(x in attestor for x in (
        "fresh_finance_custom_goals",
        "storedGoals.length != expectedGoals.length",
        "storedGoals[i].read<int>('position') != i",
        "storedGoals[i].read<String>('suggestion') != expectedGoals[i]",
    )), "M225 restored custom goals independent SQL parity missing")
    require(all(x in binding for x in (
        "checkpoint.phase != WaffraCutoverPhase.active",
        "checkpoint.sourceDigest != evidence.storage.sourceDigest",
        "automaticallyActivateSqlCipher",
    )), "M225 binding must pin encrypted startup to immutable source witness")
    require("independent disposable vault B" in attestor_test
            and "changed, extra or missing encrypted" in attestor_test
            and "certifiedEvidence: syntheticApprovedEvidence()" in binding_test,
            "M225 two-vault synthetic rehearsal or forged-digest regression missing")

    # Release notes must follow ALL modified application code; don't silently
    # issue an APK with notes predating the last UI or finance source change.
    manifest = git("log", "-1", "--format=%H", "--",
                   "docs/release/WAFFRA_APPROVED_CHANGES.txt")
    for path in sorted(p for p in ALLOWED if p.startswith("lib/")):
        latest = git("log", "-1", "--format=%H", "--", path)
        require(subprocess.run(["git", "merge-base", "--is-ancestor",
                                latest, manifest]).returncode == 0,
                "release manifest predates " + path)

    report = {
        "audit": "M147-M225", "base_main_sha": BASE_MAIN,
        "reviewed_head_sha": head, "changed_paths": sorted(changed),
        "behind": behind, "ahead": ahead, "scope_verified": True,
        "review_status": "STRICT_SOURCE_SCOPE_ONLY_NOT_DEVICE_CERTIFICATION",
        "sqlcipher_production_activated": False,
        "real_user_migration_performed": False,
        "physical_device_backup_restore_verified": False,
        "routes_in_catalog": len(inventory),
        "routes_proven_on_two_physical_devices": False,
        "sms_recovery_experimental_only": True,
        "release_authorized": False,
        "required": [
            "Every workflow for exact PR head must pass, including Android QA.",
            "Human safety/source review and exact-head merge authorization.",
            "Post-merge main SHA signed APK and verified artifact metadata.",
            "24/24 actual SQLCipher finance routes and two physical phones",
            "separately required before SQLCipher production cutover.",
        ],
    }
    out = Path("build/m147-final-review-report.json")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(report, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
