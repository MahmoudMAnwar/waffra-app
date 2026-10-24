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
    ".github/workflows/m147-final-main-review-gate.yml",
    "lib/main.dart",
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
    widget = Path("lib/waffra_widget_capture.part.dart").read_text(encoding="utf-8")
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
