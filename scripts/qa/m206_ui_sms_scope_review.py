#!/usr/bin/env python3
"""M206 strict reviewed-HEAD UI/SMS scope; retains production SQLCipher NO-GO.

Separate from the original M147 historical SHA-pinned gate. Neither audit
authorizes merge, real-device release, source cutover or Play publication.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess

APPROVED = {
    ".github/workflows/android.yml",
    ".github/scripts/run-m202-sqlcipher-binder-android.sh",
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/release/WAFFRA_APPROVED_CHANGES.txt",
    "lib/main.dart",
    "lib/storage/waffra_home_finance_persistence.dart",
    "test/m148_english_categories_legacy_backup_uat_test.dart",
    "lib/waffra_category_english.dart",
    "lib/waffra_category_catalog.dart",
    "lib/waffra_merchant_rules.dart",
    "lib/waffra_widget_capture.part.dart",
    "scripts/qa/m206_ui_sms_scope_review.py",
    "test/m127_ui_tour_backup_acceptance_test.dart",
    "test/waffra_directional_fab_receipt_corner_test.dart",
    "test/waffra_m206_day_theme_tour_sms_regression_test.dart",
    "test/waffra_oct21_regression_test.dart",
}


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], check=True, capture_output=True, text=True
    ).stdout.strip()


def require(value: bool, message: str) -> None:
    if not value:
        raise SystemExit("M206 REVIEW BLOCKED: " + message)


def main() -> None:
    head = git("rev-parse", "HEAD")
    require(head == os.environ.get("REVIEW_HEAD_SHA", "").strip(),
            "checked-out commit differs from PR's exact head SHA")
    main_ref = git("rev-parse", "refs/remotes/origin/main")
    require(git("merge-base", main_ref, head) == main_ref,
            "main is not an ancestor; reconcile changes and rerun")
    changed = set(filter(None, git("diff", "--name-only", main_ref, head).splitlines()))
    require(changed == APPROVED,
            "scope mismatch: missing=" + repr(sorted(APPROVED - changed)) +
            " unexpected=" + repr(sorted(changed - APPROVED)))

    app = Path("lib/main.dart").read_text(encoding="utf-8")
    m202_driver = Path(".github/scripts/run-m202-sqlcipher-binder-android.sh").read_text(encoding="utf-8")
    merchants = Path("lib/waffra_merchant_rules.dart").read_text(encoding="utf-8")
    widget = Path("lib/waffra_widget_capture.part.dart").read_text(encoding="utf-8")
    approved_notes = Path("docs/release/WAFFRA_APPROVED_CHANGES.txt").read_text(encoding="utf-8")
    apk_workflow = Path(".github/workflows/android.yml").read_text(encoding="utf-8")
    tests = Path("test/waffra_m206_day_theme_tour_sms_regression_test.dart").read_text(encoding="utf-8")
    workflow = Path(".github/workflows/m147-final-main-review-gate.yml").read_text(encoding="utf-8")
    release = Path("lib/storage/waffra_production_cutover_release_gate.dart").read_text(encoding="utf-8")
    source = Path("lib/storage/waffra_production_finance_source_guard.dart").read_text(encoding="utf-8")

    for marker in (
        "String appearance='light';",
        "p.getString('waffra_appearance_mode_v1')",
        "static const tourTabs=<int>[0,0,0,1,2,3];",
        "static const tourTargetKeys=<int>[-1,0,1,2,6,4];",
        "date:bankSmsDate(raw)??DateTime.now(),notes:raw,sourceType:'sms'",
        "notes:sms?message.text:notes.text",
        "child:SelectableText(entry.notes",
        "WaffraReceiptCornerBadge(count:attachmentCount,english:waffraIsEnglish)",
        "WaffraReceiptCornerBadge(count:count,english:waffraIsEnglish)",
        "_launchAddAction(",
        "if(!_acceptFabTap())return;",
        "scale:_fabPressed?0.96:1.0",
        "showWaffraSmoothDialog<SavingGoal>",
        "key:_tourKeys[1]",
    ):
        require(marker in app, "missing approved UI/SMS guard " + marker)

    for marker in ("Online\\s+Purchase", "English MADA and transfers",
                   "إشعار غير مؤكد", "Credit\\s+Transfer", "Status\\s*[:：]"):
        require(marker in app, "English bank SMS parsing guard missing: " + marker)
    for marker in ("From\\s*[:：]", "At|Merchant", "lulu hyper",
                   "صيدلية وأدوية", "توصيل الطعام"):
        require(marker in merchants, "English merchant extraction missing: " + marker)
    require("confirmed.length,56" in tests and "parsed.where((v)=>v.amount==null).length,13" in tests,
            "69-notice English bank fixture coverage missing")

    category_catalog=Path("lib/waffra_category_catalog.dart").read_text(encoding="utf-8")
    category_english=Path("lib/waffra_category_english.dart").read_text(encoding="utf-8")
    catalog_test=Path("test/m148_english_categories_legacy_backup_uat_test.dart").read_text(encoding="utf-8")
    legacy_catalog=Path("lib/storage/waffra_home_finance_persistence.dart").read_text(encoding="utf-8")
    require("version != 2 && version != 3 && version != 4" in legacy_catalog,
            "secured catalog writer must explicitly accept version 4")
    require(category_catalog.count("WaffraCategoryGroup(id:")==79,
            "79 reviewed built-in root categories required")
    require("973 subcategories" in catalog_test and
            "waffra_category_catalog_v4_installed" in app and
            "version:4" in app,"category v4 upgrade and counts missing")
    require("construction-expense" in category_catalog and
            "safety-expense" in category_catalog and
            "sustainability-expense" in category_catalog,
            "new reviewed roots missing")
    require("Home Sustainability & Energy" in category_english,
            "English labels for reviewed categories missing")
    require("WaffraOutlinedItemsCount" in app and
            "waffraSummarizeBankPaste" in app and
            "enum WaffraSnackKind" in app and
            "width:36,height:30,color:forest" in app,
            "new UI, reanalysis or compact corner absent")
    require("same clipboard content is reanalyzed" in tests and
            "pasteRevision" in app,"paste isolation regression absent")

    footer_notice_test = Path("test/waffra_directional_fab_receipt_corner_test.dart").read_text(encoding="utf-8")
    require("class WaffraFooterNoticeHost extends StatefulWidget" in app and
            "class WaffraNoticeContent extends StatelessWidget" in app and
            "bottomNavigationBar:Column(mainAxisSize:MainAxisSize.min,children:[" in app,
            "footer-integrated reusable feedback surface missing")
    require(app.count(".showSnackBar(") == 1 and
            "messenger.showSnackBar(SnackBar(" in app,
            "parallel or direct Snackbar presenters detected")
    require("if(mounted&&addFabExpanded)setState(()=>addFabExpanded=false)" in app and
            "waffraDismissFooterNotice();" in app and
            "maxLines:2" in app,
            "compact notice, consistent location or add-menu closure missing")
    require("footer notice pushes financial content up" in footer_notice_test and
            "warning, error and info keep one footprint" in footer_notice_test,
            "non-overlap and shared-status Flutter regression tests missing")

    # Emulator test execution must perform the four real Android integration
    # cases and fail shut on timeout, never report synthetic CI as production.
    for marker in (
        "flutter drive",
        "integrationDriver()",
        "timeout --signal=TERM",
        "PIPESTATUS[0]",
        "M202_ANDROID_TEST_PASS:",
        "m202_home_widget_source_binder_android_test.dart",
        "live_finance_migration_receipts_android_test.dart",
        "m120_verified_receipt_reopen_android_test.dart",
        "portable_encrypted_receipts_android_test.dart",
    ):
        require(marker in m202_driver, "M202 emulator fail-closed runner missing: " + marker)

    # The newly approved release-notes manifest is a *reviewed additional*
    # file, never a wildcard exception. Require its contents and publication
    # gate so future APKs cannot silently omit the user-approved checklist.
    for marker in (
        "شارة المرفقات",
        "الملاحظات",
        "زر الإضافة",
        "الوضع الفاتح",
        "SQLCipher",
    ):
        require(marker in approved_notes,
                "approved release notes missing content: " + marker)
    for marker in (
        "Generate and validate Waffra Release Notes TXT",
        "Gate QA APK on embedded SHA and current branch head",
        "build/Waffra-Release-Notes.txt",
        "Waffra-Android-ARM64-Release-${{ github.sha }}",
    ):
        require(marker in apk_workflow,
                "APK exact-SHA release-note safeguard missing: " + marker)

    require("notes:entry.raw,sourceType:'sms'" in widget,
            "widget bank SMS no longer preserves complete note")
    require("waffraSafeSmsTransactionTitle(parsed.title,entry.raw" in widget,
            "widget raw SMS must not replace the safe short title")
    require("child:Icon(addFabExpanded?Icons.close:Icons.add" not in app,
            "old double-moving FAB icon was reintroduced")
    for marker in (
        "all confirmed SMS routes persist full text as notes",
        "replayable tour only includes six core screens",
        "FAB launch waits for the menu collapse",
    ):
        require(marker in tests, "M206 regression coverage missing: " + marker)
    require("m206_ui_sms_scope_review.py" in workflow,
            "M206 scope review not connected to the exact-SHA gate")
    require("python3 scripts/m147_main_merge_readiness_audit.py" in workflow,
            "original M147 immutable review was removed")
    require("bool get automaticallyActivateSqlCipher => false;" in release,
            "unexpected production SQLCipher cutover")
    require("all_live_writers_not_yet_routed" in source,
            "production source safety gate changed")

    report = {
        "milestone": "M206",
        "head_sha": head,
        "base_main_sha": main_ref,
        "changed_files": sorted(changed),
        "ui_sms_scope_review": "PASS",
        "full_flutter_tests": "SEPARATE_CI_REQUIRED",
        "signed_hardware_qa": "NOT_VERIFIED",
        "sqlcipher_production_activated": False,
        "physical_two_android_device_evidence": False,
        "main_merged": False,
        "play_release_permitted": False,
        "status": "M206_SCOPE_ONLY_RELEASE_NO_GO",
    }
    out = Path("build/m147-final-review-report.json")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
