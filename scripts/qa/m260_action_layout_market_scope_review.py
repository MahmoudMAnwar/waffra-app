#!/usr/bin/env python3
"""M260 same-SHA UI and public-market-source only merge guard.

The entire diff must remain on the approved main baseline and must not touch
SQLCipher cutover, financial persistence, native Android or user data.
"""
import json
import os
import subprocess
from pathlib import Path

BASE_MAIN = "15843e8262dea20a24fbc217d74ceb129029981a"
APPROVED = {
    ".github/workflows/m147-final-main-review-gate.yml",
    ".github/workflows/android.yml",
    "docs/release/WAFFRA_APPROVED_CHANGES.txt",
    "lib/currency_converter.dart",
    "lib/main.dart",
    "lib/waffra_action_layout.dart",
    "lib/waffra_oil_market_data.dart",
    "lib/waffra_oil_market_section.dart",
    "scripts/qa/m260_action_layout_market_scope_review.py",
    "test/m260_action_layout_test.dart",
    "test/m149_backup_pin_localized_fab_trash_uat_test.dart",
}


def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()


def require(ok, why):
    if not ok:
        raise SystemExit("M260 SCOPE BLOCKED: " + why)


def content(path):
    return Path(path).read_text(encoding="utf-8")


def main():
    head = git("rev-parse", "HEAD")
    main_sha = git("rev-parse", "refs/remotes/origin/main")
    require(head == os.environ.get("REVIEW_HEAD_SHA"), "unreviewed HEAD")
    require(main_sha == BASE_MAIN, "main advanced; rebase and rerun gates")
    require(git("merge-base", main_sha, head) == main_sha,
            "not a direct descendant of approved main")
    changed = set(filter(None, git("diff", "--name-only", main_sha, head).splitlines()))
    require(changed == APPROVED, "unexpected/omitted files: " +
            repr(sorted(changed.symmetric_difference(APPROVED))))
    require(not any(p.startswith(("lib/storage/", "android/", "firebase/"))
                    for p in changed), "production finance/source change")

    app = content("lib/main.dart")
    layout = content("lib/waffra_action_layout.dart")
    require("Size(0, 52)" in layout and
            "EdgeInsets.symmetric(horizontal: 18, vertical: 12)" in layout,
            "approved adaptable height or safe insets changed")
    require(app.count("minimumSize:WaffraActionLayout.minimumSize") >= 5,
            "missing light/dark shared button minimum heights")
    require(app.count("padding:WaffraActionLayout.contentPadding") >= 5,
            "missing light/dark shared button padding")
    require("WaffraProductionFinanceAuthorityBinding.bind(" in app,
            "finance source integrity unexpectedly changed")

    market = content("lib/currency_converter.dart")
    require("waffra-open-gold-calculator" in market and
            "maxLines:2,textAlign:TextAlign.center" in market and
            "EdgeInsets.symmetric(horizontal:20,vertical:14)" in market,
            "gold call-to-action spacing or wrapping lost")
    release = content(".github/workflows/android.yml")
    require("secrets.WAFFRA_PUBLIC_EIA_KEY" in release and
            '--dart-define="WAFFRA_PUBLIC_EIA_KEY=' in release,
            "signed APK must support owner-registered official EIA commodity key")
    require('::warning::WAFFRA_PUBLIC_EIA_KEY is not configured' in release,
            "missing key must remain visible as an unverified live quote risk")

    oil = content("lib/waffra_oil_market_data.dart")
    require("fred.stlouisfed.org" in oil and "api.eia.gov" in oil,
            "verified public oil sources removed")
    require("SharedPreferences" not in oil and "Firebase" not in oil,
            "oil data must not touch financial/user storage")
    require("WaffraOilPoint" in oil and "parseFredCsv(" in oil,
            "real dated series validation removed")
    section = content("lib/waffra_oil_market_section.dart")
    require("waffra-oil-retry" in section and "waffra-oil-price-status" in section,
            "failure recovery UI removed")
    require("WaffraActionLayout.minimumSize.height" in content("test/m149_backup_pin_localized_fab_trash_uat_test.dart"),
            "historic red recycle-bin test not aligned with M260 safe minimum")
    require("testWidgets(" in content("test/m260_action_layout_test.dart"),
            "text/icon alignment regression absent")
    notes = content("docs/release/WAFFRA_APPROVED_CHANGES.txt")
    require("[M260]" in notes and "NO-GO" in notes,
            "approved notes/security boundary missing")
    report = Path("build/m147-final-review-report.json")
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps({
        "milestone": "M260",
        "head_sha": head,
        "base_main": main_sha,
        "files_checked": sorted(changed),
        "scope": "APP_WIDE_BUTTON_THEME_AND_PUBLIC_OIL_ERROR_UI_ONLY",
        "sqlcipher_production": "NO_GO",
        "physical_device_approval": "REQUIRED",
        "apk_approval": "NOT_GRANTED",
    }, indent=2) + "\n", encoding="utf-8")
    print("M260 PASS: exact-main UI/source scope only:", head)


if __name__ == "__main__":
    main()
