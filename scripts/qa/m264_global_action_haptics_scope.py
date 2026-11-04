#!/usr/bin/env python3
"""M264 app-wide accepted action vibration safety, main SHA pinned."""
import json
import os
import subprocess
from pathlib import Path

BASE = "524b03c98535637b5640eaba87d0a2f85048f6ff"
UI_FILES = {
    "lib/main.dart",
    "lib/currency_converter.dart",
    "lib/waffra_categories_page.part.dart",
    "lib/waffra_deleted_item_card.part.dart",
    "lib/waffra_financial_tools.dart",
    "lib/waffra_footer.dart",
    "lib/waffra_gold_market_section.dart",
    "lib/waffra_oil_market_section.dart",
    "lib/waffra_market_accordion.dart",
    "lib/waffra_pdf_reader.dart",
    "lib/waffra_recurring_trash.part.dart",
    "lib/waffra_smart_analysis.part.dart",
    "lib/waffra_verified_receipt_panel.dart",
    "lib/waffra_widget_capture.part.dart",
    "lib/waffra_account_deletion.dart",
}
APPROVED = UI_FILES | {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/release/WAFFRA_APPROVED_CHANGES.txt",
    "lib/waffra_haptic_feedback.dart",
    "test/m264_app_wide_action_haptics_test.dart",
    "test/waffra_directional_fab_receipt_corner_test.dart",
    "test/waffra_oct21_regression_test.dart",
    "test/m149_backup_pin_localized_fab_trash_uat_test.dart",
    "test/m150_file_backup_leaf_categories_uat_test.dart",
    "test/m224_verified_pull_refresh_dialog_test.dart",
    "test/m259_market_source_contract_test.dart",
    "scripts/qa/m264_global_action_haptics_scope.py",
}

def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()

def require(ok, reason):
    if not ok:
        raise SystemExit("M264 BLOCKED: " + reason)

def read(path):
    return Path(path).read_text(encoding="utf-8")

def main():
    head = git("rev-parse", "HEAD")
    main = git("rev-parse", "refs/remotes/origin/main")
    require(os.environ.get("REVIEW_HEAD_SHA") == head, "unreviewed commit")
    require(main == BASE, "main moved; rebuild and retest")
    require(git("merge-base", main, head) == main, "unexpected ancestry")
    diff = set(filter(None, git("diff", "--name-only", main, head).splitlines()))
    require(diff == APPROVED,
            "unexpected files " + repr(sorted(diff.symmetric_difference(APPROVED))))
    require(not any(p.startswith(("android/", "firebase/", "lib/storage/"))
                    for p in diff), "sensitive finance/native changes")
    utility = read("lib/waffra_haptic_feedback.dart")
    require(all(x in utility for x in (
        "HapticFeedback.lightImpact()", "action == null ? null",
        "impact();", "static VoidCallback? tap(", "ValueChanged<T>? selection<T>",
        "_sameGestureMicros", "_lastImpactMicros",
    )), "common accepted-action feedback contract missing")
    wrappers = 0
    for path in UI_FILES:
        s = read(path)
        require("WaffraHaptics.tap(" in s or "WaffraHaptics.selection(" in s,
                "missing haptic path: " + path)
        wrappers += s.count("WaffraHaptics.tap(") + s.count("WaffraHaptics.selection(")
        if not path.endswith(".part.dart"):
            require("import 'waffra_haptic_feedback.dart';" in s,
                    "missing haptic import " + path)
    require(wrappers > 250, "not enough button and menu actions covered")
    main_source = read("lib/main.dart")
    require("if(!_acceptFabTap())return;" in main_source and
            "HapticFeedback.lightImpact()" in main_source,
            "accepted FAB response removed")
    require("onTap:WaffraHaptics.tap(()async{\\n     if(!_acceptFabTap())"
            not in main_source, "FAB vibration doubled")
    require("onChanged:(_)=>setState(" in main_source,
            "text entry should remain non-haptic")
    tests = read("test/m264_app_wide_action_haptics_test.dart")
    require("disabled action remains disabled" in tests and
            "same gesture nested actions do not double vibrate" in tests and
            "menu/dropdown selection vibrates, not typing" in tests,
            "safety regressions missing")
    require("[M264]" in read("docs/release/WAFFRA_APPROVED_CHANGES.txt"),
            "release note missing")
    report = Path("build/m147-final-review-report.json")
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps({
        "milestone": "M264",
        "source_sha": head,
        "base_main": main,
        "changed": sorted(diff),
        "wrapped_callbacks": wrappers,
        "scope": "APP_WIDE_ENABLED_ACTION_LIGHT_HAPTICS_ONLY",
        "sqlcipher_production": "NO_GO",
        "signed_apk": "NOT_CERTIFIED",
        "physical_device_vibration": "OWNER_QA_REQUIRED",
    }, indent=2) + "\n", encoding="utf-8")
    print("M264 PASS: accepted app-wide light impacts, no finance changes", head)

if __name__ == "__main__":
    main()
