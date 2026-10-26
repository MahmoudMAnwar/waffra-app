#!/usr/bin/env python3
"""M265 exact-SHA union of M261/M262/M264, production SQLCipher still NO-GO."""
import json, os, subprocess
from pathlib import Path
BASE="524b03c98535637b5640eaba87d0a2f85048f6ff"
FILES=set(""".github/workflows/m147-final-main-review-gate.yml
docs/release/WAFFRA_APPROVED_CHANGES.txt
lib/main.dart
lib/currency_converter.dart
lib/waffra_account_deletion.dart
lib/waffra_categories_page.part.dart
lib/waffra_deleted_item_card.part.dart
lib/waffra_financial_tools.dart
lib/waffra_footer.dart
lib/waffra_gold_market_section.dart
lib/waffra_haptic_feedback.dart
lib/waffra_market_accordion.dart
lib/waffra_oil_market_data.dart
lib/waffra_oil_market_section.dart
lib/waffra_pdf_reader.dart
lib/waffra_recurring_trash.part.dart
lib/waffra_smart_analysis.part.dart
lib/waffra_verified_receipt_panel.dart
lib/waffra_widget_capture.part.dart
scripts/qa/m261_keyless_eia_scope_review.py
scripts/qa/m262_notes_original_sms_scope_review.py
scripts/qa/m263_market_sms_combined_main_scope_review.py
scripts/qa/m264_global_action_haptics_scope.py
scripts/qa/m265_combined_pr_main_gate.py
test/m149_backup_pin_localized_fab_trash_uat_test.dart
test/m150_file_backup_leaf_categories_uat_test.dart
test/m224_verified_pull_refresh_dialog_test.dart
test/m227_gold_currency_original_sms_home_test.dart
test/m259_market_source_contract_test.dart
test/m259_oil_quotes_test.dart
test/m262_bank_sms_notes_separation_test.dart
test/m264_app_wide_action_haptics_test.dart
test/waffra_directional_fab_receipt_corner_test.dart
test/waffra_m206_day_theme_tour_sms_regression_test.dart
test/waffra_oct21_regression_test.dart
""".strip().splitlines())
def git(*args):
    return subprocess.check_output(["git", *args],text=True).strip()
def expect(ok, why):
    if not ok: raise SystemExit("M265 BLOCKED: "+why)
def read(p):
    return Path(p).read_text(encoding="utf-8")
def main():
    head=git("rev-parse","HEAD")
    main=git("rev-parse","refs/remotes/origin/main")
    expect(head==os.environ.get("REVIEW_HEAD_SHA"),"head changed")
    expect(main==BASE,"main moved; rebase and rerun")
    expect(git("merge-base", main, head)==main,"unexpected ancestry")
    changed=set(filter(None,git("diff","--name-only",main,head).splitlines()))
    expect(changed==FILES,"unexpected/missing files: "+repr(sorted(changed.symmetric_difference(FILES))))
    expect(not any(p.startswith(("lib/storage/","android/","firebase/")) for p in changed),"storage or native change")
    code=read("lib/main.dart")
    expect("protectedOriginalSms:originalBankSms" in code and
           "readProtectedOriginalSms(entry.id)" in code and
           "Key('waffra-transaction-personal-notes')" in code and
           "Key('waffra-transaction-protected-bank-sms')" in code and
           "if(entry.sourceType=='sms'){" in code,
           "original encrypted SMS and editable notes are not independent")
    oil=read("lib/waffra_oil_market_data.dart")
    oilUI=read("lib/waffra_oil_market_section.dart")
    expect(all(t in oil for t in ("RBRTEd.htm","RWTCd.htm","RNGWHHDD.htm",
              "parseEiaDailyHtml(","_fetchPublicSources(api)")) and
           "صفحات الأسعار اليومية الرسمية" in oilUI,
           "verified public oil feed missing")
    haptics=read("lib/waffra_haptic_feedback.dart")
    expect(all(t in haptics for t in (
         "HapticFeedback.lightImpact()","static VoidCallback? tap(",
         "static VoidCallback tapRequired(","selectionRequired<T>","action == null ? null",
         "_sameGestureMicros")),"light feedback safety contract missing")
    ui=[x for x in FILES if x.startswith("lib/") and
        x not in ("lib/waffra_haptic_feedback.dart","lib/waffra_oil_market_data.dart")]
    count=sum(read(p).count("WaffraHaptics.tap(")+read(p).count("WaffraHaptics.tapRequired(")+
              read(p).count("WaffraHaptics.selection(")+
              read(p).count("WaffraHaptics.selectionRequired(") for p in ui)
    expect(count>=300,"accepted app-wide haptics incomplete: "+str(count))
    expect(code.count("HapticFeedback.lightImpact()")==1,
           "FAB must retain precisely one existing light impact")
    expect(all(x in read("docs/release/WAFFRA_APPROVED_CHANGES.txt")
               for x in ("[M261]","[M262]","[M263]","[M264]","[M265]")),
           "release notes incomplete")
    p=Path("build/m147-final-review-report.json")
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps({
        "milestone":"M265", "head_sha":head, "base_main":main,
        "files":sorted(changed),"wrapped_callbacks":count,
        "scope":"COMBINED_OIL_SMS_NOTES_ACTION_HAPTICS",
        "sqlcipher_production":"NO_GO",
        "physical_android":"NOT_VERIFIED",
        "signed_main_apk":"NOT_YET_VERIFIED"},indent=2)+"\n",encoding="utf-8")
    print("M265 PASS: combined exact-main scope",head)
if __name__=="__main__":main()
