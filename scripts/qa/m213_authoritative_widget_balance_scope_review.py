#!/usr/bin/env python3
"""M213 exact-head finance source audit: no customer SQLCipher activation."""
import json
import os
import subprocess
from pathlib import Path

APPROVED={
    "lib/main.dart",
    "lib/waffra_widget_capture.part.dart",
    "lib/storage/waffra_authoritative_widget_balance.dart",
    "test/waffra_widget_balance_source_authority_test.dart",
    "test/storage/live_legacy_finance_writer_coordinator_test.dart",
    "test/waffra_concept2_final_visual_test.dart",
    ".github/workflows/m147-final-main-review-gate.yml",
    "scripts/qa/m213_authoritative_widget_balance_scope_review.py",
    "docs/release/WAFFRA_APPROVED_CHANGES.txt",
    "docs/qa/m213-authoritative-widget-balance-source.md",
}
def git(*args):
    return subprocess.run(["git",*args],check=True,capture_output=True,
                          text=True).stdout.strip()
def require(value,what):
    if not value: raise SystemExit("M213 BLOCKED: "+what)
def txt(path): return Path(path).read_text(encoding="utf-8")
def main():
    head=git("rev-parse","HEAD")
    base=git("rev-parse","refs/remotes/origin/main")
    require(head==os.environ.get("REVIEW_HEAD_SHA","").strip(),
            "exact-head mismatch")
    require(git("merge-base",base,head)==base,"main moved")
    changed=set(filter(None,git("diff","--name-only",base,head).splitlines()))
    require(changed==APPROVED,
            "unapproved files: "+repr(sorted(changed ^ APPROVED)))
    main=txt("lib/main.dart")
    widget=txt("lib/waffra_widget_capture.part.dart")
    projection=txt("lib/storage/waffra_authoritative_widget_balance.dart")
    tests=txt("test/waffra_widget_balance_source_authority_test.dart")
    wf=txt(".github/workflows/m147-final-main-review-gate.yml")
    release=txt("docs/release/WAFFRA_APPROVED_CHANGES.txt")
    no_go=txt("lib/storage/waffra_production_cutover_release_gate.dart")
    legacy=txt("lib/storage/waffra_home_finance_persistence.dart")
    for src,which in [(main,"Home"),(widget,"Widget")]:
        require("route:WaffraFinanceRoute.widgetBalanceRefresh" in src,
                which+" unverified widget balance route")
        require("WaffraAuthoritativeWidgetBalance.netHalalas(" in src,
                which+" legacy in-memory balance projection")
        require("balance:'***',negative:false,hidden:true" in src,
                which+" stale balance not concealed on source failure")
    require("refreshVerifiedWidgetBalance:_refreshWidget" in main,
            "Home eye button does not reload source")
    for marker in ("ids.add(","value.isFinite","WaffraRecurringPolicy.toHalalas",
                   "jsonDecode(ledgerRaw)"):
        require(marker in projection,"invalid pure ledger guard: "+marker)
    require("M213 real ledger projection" in tests and
            "M213 invalid, duplicated or unverified ledger" in tests,
            "missing negative and positive regression tests")
    require("M213 SHA-pinned" in wf and
            "m213_authoritative_widget_balance_scope_review.py" in wf,
            "M213 exact SHA CI step missing")
    require("firstCommitted.future" in txt(
                "test/storage/live_legacy_finance_writer_coordinator_test.dart") and
            "firstCommitted.complete();" in txt(
                "test/storage/live_legacy_finance_writer_coordinator_test.dart"),
            "native-lock regression still assumes OS acquisition FIFO ordering")
    require("refreshVerifiedWidgetBalance: () async {}" in txt(
                "test/waffra_concept2_final_visual_test.dart"),
            "visual-only balance header fixture is missing required callback")
    require("[23] M213" in release,"main APK release notes weren't updated")
    require("bool get automaticallyActivateSqlCipher => false;" in no_go,
            "production SQLCipher marker unexpectedly changed")
    require("WaffraLegacySmsNotesPrivacyGate.rejectConfirmedSmsNotes(copied)" in legacy,
            "M207 original SMS privacy guard missing")
    report={"milestone":"M213","head":head,"scope":sorted(changed),
            "source_bound_widget_refresh":"FLUTTER_TEST_REQUIRED",
            "physical_devices_accepted":0,
            "live_verified_routes":0,
            "production_sqlcipher_active":False,
            "status":"WIDGET_BALANCE_ROUTE_CI_ONLY_NO_GO"}
    dest=Path("build/m147-final-review-report.json")
    dest.parent.mkdir(parents=True,exist_ok=True)
    dest.write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps(report))
if __name__=="__main__": main()
