#!/usr/bin/env python3
"""M259 exact-main market UI and pull-refresh read-only scope gate.

Strict QA check, not SQLCipher production certification or APK signing.
"""
from pathlib import Path
import os
import subprocess

BASE_MAIN = "8a460fa3d537ee7e8343b01e49d794140e66652a"
APPROVED = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/release/WAFFRA_APPROVED_CHANGES.txt",
    "scripts/qa/m259_market_scroll_main_scope_review.py",
    "lib/main.dart",
    "lib/waffra_categories_page.part.dart",
    "lib/waffra_pull_refresh_scroll_settle.dart",
    "lib/currency_converter.dart",
    "lib/waffra_market_accordion.dart",
    "lib/waffra_oil_market_data.dart",
    "lib/waffra_oil_market_section.dart",
    "test/m224_verified_pull_refresh_dialog_test.dart",
    "test/storage/production_custom_goal_source_routing_test.dart",
    "test/m258_pull_refresh_scroll_settle_test.dart",
    "test/m258_finance_refresh_wiring_test.dart",
    "test/m259_oil_quotes_test.dart",
    "test/m259_market_accordion_test.dart",
    "test/m259_market_source_contract_test.dart",
}

def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()

def check(value,why):
    if not value:
        raise SystemExit("M259 SAFETY BLOCKED: " + why)

def source(path):
    return Path(path).read_text(encoding="utf-8")

def main():
    head=git("rev-parse","HEAD")
    main_sha=git("rev-parse","refs/remotes/origin/main")
    check(head==os.environ.get("REVIEW_HEAD_SHA"),"candidate source SHA drift")
    check(main_sha==BASE_MAIN,"main changed; rebase and repeat all QA")
    check(git("merge-base",BASE_MAIN,head)==BASE_MAIN,
          "not a direct descendant of approved main")
    changed=set(filter(None,git("diff","--name-only",BASE_MAIN,head).splitlines()))
    check(changed==APPROVED,"unexpected/omitted files: "+repr(sorted(changed^APPROVED)))
    check(not any(p.startswith(("lib/storage/","android/","firebase/")) for p in changed),
          "financial data source or native Android has changed")
    check("pubspec.yaml" not in changed and "pubspec.lock" not in changed,
          "dependencies not authorized for visual-only release")
    main=source("lib/main.dart")
    for marker in (
        "WaffraProductionFinanceAuthorityBinding.bind(",
        "_financeAuthority.load(",
        "requireIntegrity()",
        "WaffraFinanceRoute.dashboardRead",
        "await _financialWriteQueue.drain();",
        "_refreshAndSettle(",
        "ClampingScrollPhysics(parent:AlwaysScrollableScrollPhysics())",
    ):
        check(marker in main,"lost finance/refresh guarantee: "+marker)
    converter=source("lib/currency_converter.dart")
    for marker in ("WaffraMarketAccordionCard(","id:'currency'","id:'gold'",
                   "id:'oil'","WaffraGoldMarketSection(","WaffraGoldCalculatorPage(",
                   "WaffraOilMarketSection(","Future<void> convert()",
                   "onRefresh:_pullRefresh"):
        check(marker in converter,"missing approved market feature: "+marker)
    oil=source("lib/waffra_oil_market_data.dart")
    check("api.eia.gov" in oil and "RBRTE" in oil and "RWTC" in oil,
          "official EIA quote source missing")
    check("EIA API key not configured" in oil,"missing honest no-key state")
    check("SharedPreferences" not in oil and "Firebase" not in oil,
          "market UI must remain separate from finance/profile data")
    for file in ("test/m258_pull_refresh_scroll_settle_test.dart",
                 "test/m258_finance_refresh_wiring_test.dart",
                 "test/m259_oil_quotes_test.dart",
                 "test/m259_market_accordion_test.dart",
                 "test/m259_market_source_contract_test.dart"):
        check("test(" in source(file) or "testWidgets(" in source(file),
              "required UI/source QA missing "+file)
    notes=source("docs/release/WAFFRA_APPROVED_CHANGES.txt")
    check("[M258–M259]" in notes and "SQLCipher" in notes
          and "NO-GO" in notes,"release notes or NO-GO boundary missing")
    import json
    report_path=Path("build/m147-final-review-report.json")
    report_path.parent.mkdir(parents=True,exist_ok=True)
    report_path.write_text(json.dumps({
        "milestone":"M259",
        "head_sha":head,
        "approved_main_sha":BASE_MAIN,
        "files_checked":sorted(changed),
        "scope":"UI_AND_PUBLIC_COMMODITY_DATA_ONLY",
        "apk":"NOT_AUTHORIZED_BY_THIS_REPORT",
        "sqlcipher_production":"NO_GO",
        "physical_device_tests":"REQUIRED",
    },indent=2)+"\n",encoding="utf-8")
    print("M259 PASS (source scope only): "+head)

if __name__=="__main__":
    main()
