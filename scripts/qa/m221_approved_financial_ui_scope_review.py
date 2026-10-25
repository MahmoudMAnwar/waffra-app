#!/usr/bin/env python3
"""Exact-head M221 approved UI review; must not activate SQLCipher."""
import json
import os
import subprocess
from pathlib import Path

SCOPE = {
 ".github/workflows/m147-final-main-review-gate.yml",
 "docs/qa/m221-approved-financial-ui-subscription-layout.md",
 "docs/release/WAFFRA_APPROVED_CHANGES.txt",
 "lib/main.dart",
 "lib/waffra_categories_page.part.dart",
 "lib/waffra_financial_tools.dart",
 "scripts/qa/m221_approved_financial_ui_scope_review.py",
 "test/m221_approved_financial_ui_test.dart",
}

def git(*args):
 return subprocess.run(["git",*args],check=True,capture_output=True,
                       text=True).stdout.strip()

def assert_ok(ok,why):
 if not ok: raise SystemExit("M221 BLOCKED: "+why)

def content(path): return Path(path).read_text(encoding="utf-8")

def main():
 head=git("rev-parse","HEAD")
 base=git("rev-parse","refs/remotes/origin/main")
 assert_ok(head==os.environ.get("REVIEW_HEAD_SHA","").strip(),"SHA mismatch")
 assert_ok(git("merge-base",base,head)==base,"main not ancestor of candidate")
 changed=set(filter(None,git("diff","--name-only",base,head).splitlines()))
 assert_ok(changed==SCOPE,"unapproved file paths: "+repr(sorted(changed^SCOPE)))
 app=content("lib/main.dart")
 categories=content("lib/waffra_categories_page.part.dart")
 financial=content("lib/waffra_financial_tools.dart")
 tests=content("test/m221_approved_financial_ui_test.dart")
 review=content(".github/workflows/m147-final-main-review-gate.yml")
 notes=content("docs/release/WAFFRA_APPROVED_CHANGES.txt")
 gate=content("lib/storage/waffra_production_cutover_release_gate.dart")
 for marker in (
   "bool get isUserAdded=>origin=='user';",
   "'origin':origin",
   "origin:initial?.origin??'user'",
   "bool categoryMineOnly=false;",
   "HapticFeedback.lightImpact()",
   "Widget goalsPage(){",
   "Widget recurringPage(){",
   "WaffraOutlinedItemsCount(",
   "WaffraDeletedItemsButton(",
   "minimumSize:const Size(0,48)",
   "Key('waffra-recurring-count-badge')",
   "Switch.adaptive(value:recurringRemindersEnabled",
   "onAddRecurring:(candidate)=>recurringDialog(",
 ):
  assert_ok(marker in app,"missing real UI connection: "+marker)
 for marker in (
   "categoryMineOnly",
   "'مضاف بواسطتي'",
   "if(categoryMineOnly&&!root.isUserAdded",
   "c.isUserAdded",
   "Deleted categories",
   "Main categories",
 ):
  assert_ok(marker in categories,"category requirement not wired: "+marker)
 for marker in (
   "class WaffraSubscriptionScreen extends StatefulWidget",
   "'كشف الاشتراكات'",
   "detectWaffraSubscriptions(widget.items)",
   "onAddRecurring!(candidate)",
   "'تجاهل'",
   "'اشتراكات محتملة'",
   "'ملاحظات ذكية'",
   "'لا توجد اشتراكات محتملة حاليًا'",
 ):
  assert_ok(marker in financial,"financial tools subscription UI missing: "+marker)
 assert_ok("WaffraSubscriptionScreen" in app and
           "'كشف الاشتراكات'" in app,"real financial tools route absent")
 assert_ok("M221" in notes and "M221 SHA-pinned" in review and
           "m221_approved_financial_ui_scope_review.py" in review,
           "release/CI missing")
 assert_ok(tests.count("test(")+tests.count("testWidgets(")>=8,
           "insufficient scenario coverage")
 assert_ok("bool get automaticallyActivateSqlCipher => false;" in gate,
           "production SQLCipher cutover unexpectedly enabled")
 assert_ok("origin:origin" in app and
           "origin:initial?.origin??'user'" in app,
           "category origin not durable across manual edit")
 report={"milestone":"M221","head":head,"main":base,"scope":sorted(changed),
         "approved_ui_wired":True,"subscription_data_is_local":True,
         "physical_haptics_tested":False,"sqlcipher_production":"NO_GO",
         "signed_release":"NOT_AUTHORIZED"}
 out=Path("build/m147-final-review-report.json")
 out.parent.mkdir(parents=True,exist_ok=True)
 out.write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
 print(json.dumps(report))

if __name__=="__main__": main()
