#!/usr/bin/env python3
"""Exact-main scope and source safety for 10 additive Waffra tools (NO CUTOVER)."""
from __future__ import annotations
import json
import os
import subprocess
from pathlib import Path

FILES = {
    "lib/main.dart",
    "lib/waffra_smart_features.dart",
    "lib/waffra_today_picker.dart",
    "lib/waffra_financial_tools.dart",
    "lib/waffra_categories_page.part.dart",
    "test/m268_smart_features_ten_calendar_art_test.dart",
    "docs/release/WAFFRA_APPROVED_CHANGES.txt",
    "scripts/qa/m268_scope_review.py",
    ".github/workflows/m268-smart-features.yml",
    ".github/workflows/m147-final-main-review-gate.yml",
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
    demand("class WaffraSmartFeaturesPage" in source,
           "additive feature screen unavailable")
    for topic in ("runway","subscription","simulation","guardian","assistant",
                  "season","wallet","challenge","flow","emergency"):
        demand("'"+topic+"'" in source,"missing feature: "+topic)
    main_text=Path("lib/main.dart").read_text()
    demand("waffra-m268-tools-entry" in main_text and
           "openSmartFeatures()" in main_text,"Home entry or route missing")
    demand(main_text.count("waffraPickDateWithToday(")==5,
           "all 5 existing Material date pickers must keep Today action")
    demand("waffra-recurring-calendar-today" in main_text,
           "inline recurring calendar Today missing")
    calendar=Path("lib/waffra_financial_tools.dart").read_text()
    demand("waffra-financial-calendar-today" in calendar,
           "financial calendar Today missing")
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
      "production_sqlcipher_activated":False,"phone_production_attested":False,
      "status":"ILLUSTRATED_PLANNING_UX_QA_ONLY_NO_CUTOVER"}
    p=Path("build/m147-final-review-report.json")
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps(report,indent=2))
if __name__=="__main__":
    main()
