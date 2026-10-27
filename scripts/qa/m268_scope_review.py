#!/usr/bin/env python3
"""Exact-main scope and source safety for 10 additive Waffra tools (NO CUTOVER)."""
from __future__ import annotations
import json
import os
import subprocess
from pathlib import Path

FILES = {
    ".github/workflows/m147-final-main-review-gate.yml",
    ".github/workflows/m267-android-exact-apk-identity.yml",
    ".github/workflows/m268-smart-features.yml",
    "docs/release/WAFFRA_APPROVED_CHANGES.txt",
    "lib/currency_converter.dart",
    "lib/main.dart",
    "lib/waffra_categories_page.part.dart",
    "lib/waffra_financial_tools.dart",
    "lib/waffra_footer.dart",
    "lib/waffra_gold_calculator.dart",
    "lib/waffra_search.dart",
    "lib/waffra_smart_features.dart",
    "lib/waffra_today_picker.dart",
    "scripts/qa/m268_scope_review.py",
    "test/m268_smart_features_ten_calendar_art_test.dart",
    "test/waffra_design_preservation_test.dart",
    "test/waffra_m206_day_theme_tour_sms_regression_test.dart",
    "test/waffra_oct21_regression_test.dart",
    "test/waffra_search_normalization_test.dart",
}
def git(*args):
    return subprocess.check_output(["git",*args],text=True).strip()
def demand(value,reason):
    if not value:
        raise SystemExit("M268 BLOCKED: "+reason)
def main():
    head=git("rev-parse","HEAD")
    expected=os.environ.get("REVIEW_HEAD_SHA","")
    demand(bool(expected) and head==expected,"not pinned to reviewed PR head")
    base=git("rev-parse","refs/remotes/origin/main")
    demand(git("merge-base",base,head)==base,"branch not based on current main")
    changed=set(filter(None,git("diff","--name-only",base+"...HEAD").splitlines()))
    demand(changed==FILES,"unreviewed or missing files: "+str(sorted(changed^FILES)))
    finance_modules=git("diff","--name-only",base+"...HEAD","--","lib/storage","native","firebase")
    demand(not finance_modules,"no storage, key, bank or native changes allowed")
    source=Path("lib/waffra_smart_features.dart").read_text()
    for forbidden in ("SharedPreferences","FirebaseFirestore","MethodChannel(",
        "saveCaptured(","commitConfirmedSms(","http.get(","readProtectedOriginalSms("):
        demand(forbidden not in source,"smart tools cannot access persistence or network: "+forbidden)
    demand("production_release_allowed" not in source,"no release certification from UI")
    foreign=Path(".github/workflows/m267-android-exact-apk-identity.yml").read_text()
    demand("github.head_ref == 'qa/m267-exact-sha-two-android-identity-20261027'" in foreign,
           "M267 unrelated-source review must be branch-scoped")

    demand("class WaffraSmartFeaturesPage" in source,
           "additive feature screen unavailable")
    for topic in ("runway","subscription","simulation","guardian","assistant",
                  "season","wallet","challenge","flow","emergency"):
        demand("'"+topic+"'" in source,"missing feature: "+topic)
    main_text=Path("lib/main.dart").read_text()
    footer=Path("lib/waffra_footer.dart").read_text()
    demand("static const itemCount=6" in footer,
           "footer must contain six destinations")
    demand("'الأقسام','الأدوات','الأهداف'" in footer and
           "'Categories','Smart tools','Goals'" in footer,
           "smart tools must be in slot three, after categories")
    demand("case 2:return _smartToolsTab();" in main_text and
           "embedded:true" in main_text and
           "waffra-m268-footer-page" in main_text,
           "smart tools must render in footer, not navigate away")
    demand("waffra-m268-tools-entry" not in main_text,
           "Home must not contain a redundant ten-tool entry")
    demand("waffra-m268-accordion-" in source and
           "AnimatedSize(" in source and
           "waffra-m268-expanded-" in source,
           "missing in-place animated accordion")
    search=Path("lib/waffra_search.dart").read_text()
    for marker in ("[أإآٱ]", "waffraSearchMatches", "waffraSearchAny"):
        demand(marker in search, "Arabic tolerant search utility missing: "+marker)
    for file in ("lib/main.dart","lib/currency_converter.dart",
                 "lib/waffra_gold_calculator.dart"):
        demand("waffraSearchAny(" in Path(file).read_text(),
               "search field not connected in "+file)
    demand("waffraSearchAny(" in Path("lib/waffra_categories_page.part.dart").read_text(),
           "category search must normalize both sides")
    demand(main_text.count("waffraPickDateWithToday(")==5,
           "all 5 existing Material date pickers must keep Today action")
    demand("waffra-recurring-calendar-today" in main_text,
           "inline recurring calendar Today missing")
    calendar=Path("lib/waffra_financial_tools.dart").read_text()
    demand("waffra-financial-calendar-today" in calendar,
           "financial calendar Today missing")
    # The full app needs JNI in the distributed QA APK. A compilation-only
    # PR artifact previously omitted libdartjni.so and crashed on startup.
    # Keep the native-library refusal before any artifact publication.
    preview=Path(".github/workflows/m147-final-main-review-gate.yml").read_text()
    for marker in ("Re-resolve plugins after generating Android host",
                   "Install the approved Waffra launcher artwork",
                   "Refuse APK missing native runtime libraries",
                   "'libdartjni.so'","'libsqlite3mc.so'"):
        demand(marker in preview,"preview APK native startup gate missing: "+marker)
    demand(preview.index("Refuse APK missing native runtime libraries") <
           preview.index("Attach unapproved-for-production APK for device QA"),
           "cannot publish an unchecked native APK")
    # The fast PR compile uses an unregistered Android app ID and a preview
    # signing identity. It MUST not silently advertise working Google login,
    # Widget/quick share or full native parity in the distributed artifact.
    for marker in ("WAFFRA_COMPILE_ONLY_PREVIEW=true",
                   "WAFFRA_PREVIEW_LIMITATIONS.txt",
                   "Google authentication: NOT SUPPORTED",
                   "com.waffra.waffra (not registered with Firebase)"):
        demand(marker in preview,"CI-only APK must be labeled as limited: "+marker)
    for marker in ("waffraCompileOnlyQaPreview",
                   "waffraGooglePreviewNotice",
                   "if(waffraCompileOnlyQaPreview)"):
        demand(marker in main_text,
               "user must see an accurate Google-login preview limitation: "+marker)
    demand("Configure Firebase Google Sign-In" in
           Path(".github/workflows/android.yml").read_text(),
           "main signed Google login workflow unexpectedly removed")
    release=Path("lib/storage/waffra_production_cutover_release_gate.dart").read_text()
    demand("bool get automaticallyActivateSqlCipher => false;" in release,
           "production activation guard changed")
    guard=Path("lib/storage/waffra_production_finance_source_guard.dart").read_text()
    demand("all_live_writers_not_yet_routed" in guard,
           "SQLCipher source guard removed")
    demand("[M268]" in Path("docs/release/WAFFRA_APPROVED_CHANGES.txt").read_text(),
           "approved release changes missing")
    report={"milestone":"M268","head":head,"base":base,
      "scope":sorted(changed),"financial_storage_changed":False,
      "app_feature_screens":10,"material_date_pickers":5,
      "footer_smart_tools_slot":2,"arabic_search_folded":True,
      "production_sqlcipher_activated":False,"phone_production_attested":False,
      "status":"ILLUSTRATED_PLANNING_UX_QA_ONLY_NO_CUTOVER"}
    p=Path("build/m147-final-review-report.json")
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps(report,indent=2))
if __name__=="__main__":
    main()
