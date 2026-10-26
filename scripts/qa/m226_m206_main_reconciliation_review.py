#!/usr/bin/env python3
"""M226 exact-head, actual-main two-parent M206 reconciliation audit.

Unlike the M224 pinned-source audit, this checks latest-main ancestry and
restricts changes to the approved M206 UI, its tests, notes and this review.
It never authorizes SQLCipher production or use of real bank SMS.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess

M206_HEAD = "8c65a3743ccc55e1b228671355e78a88296b4917"
EXPECTED_PATHS = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/release/WAFFRA_APPROVED_CHANGES.txt",
    "lib/main.dart",
    "scripts/qa/m226_m206_main_reconciliation_review.py",
    "test/waffra_m206_day_theme_tour_sms_regression_test.dart",
}

def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True).strip()

def require(condition: bool, reason: str) -> None:
    if not condition:
        raise SystemExit("M226 RECONCILIATION BLOCKED — " + reason)

def main() -> None:
    head = git("rev-parse", "HEAD")
    expected = os.environ.get("REVIEW_HEAD_SHA", "")
    require(len(expected) == 40 and head == expected, "CI did not checkout exact PR head")
    current_main = git("rev-parse", "refs/remotes/origin/main")
    # Candidate consists of the original *two-parent* content reconciliation
    # followed by this separate, auditable QA-gate adjustment commit.
    merge = git("rev-parse", "HEAD^")
    parents = git("rev-list", "--parents", "-n", "1", merge).split()[1:]
    require(len(parents) == 2, "expected explicit conflict-resolved two-parent merge")
    require(parents[0] == current_main, "main moved since reconciliation; recompute merge")
    require(parents[1] == M206_HEAD, "M206 approved source parent mismatch")
    changed = set(filter(None, git("diff", "--name-only", current_main, head).splitlines()))
    require(changed == EXPECTED_PATHS, "unexpected file changes: " + repr(sorted(changed ^ EXPECTED_PATHS)))
    require(git("merge-base", current_main, head) == current_main,
            "candidate must descend from current main")
    code = Path("lib/main.dart").read_text(encoding="utf-8")
    test = Path("test/waffra_m206_day_theme_tour_sms_regression_test.dart").read_text(encoding="utf-8")
    notes = Path("docs/release/WAFFRA_APPROVED_CHANGES.txt").read_text(encoding="utf-8")
    privacy = Path("lib/storage/waffra_home_finance_persistence.dart").read_text(encoding="utf-8")
    release = Path("lib/storage/waffra_production_cutover_release_gate.dart").read_text(encoding="utf-8")
    workflow = Path(".github/workflows/m147-final-main-review-gate.yml").read_text(encoding="utf-8")
    required_ui = (
        "String appearance='light';",
        "static const tourTabs=<int>[0,0,0,1,2,3];",
        "floatingActionButtonLocation:WaffraDirectionalFabLocation(english:waffraIsEnglish)",
        "floatingActionButtonAnimator:const WaffraStationaryFabAnimator()",
        "WaffraReceiptCornerBadge(count:attachmentCount,english:waffraIsEnglish)",
        "notes:sms?message.text:notes.text",
        "child:SelectableText(entry.notes",
        "await Future<void>.delayed(waffraMotion(165));",
        "await Future<void>.delayed(waffraMotion(110));",
        "duration:waffraMotion(220)",
        "now.difference(_lastFabTapAt!)<const Duration(milliseconds:380)",
    )
    require(all(token in code for token in required_ui), "required approved M206 code missing")
    require("waffraMotion(165)" in test and "Duration(milliseconds:380)" in test,
            "matching M206 FAB regression test missing")
    require("WaffraLegacySmsNotesPrivacyGate.rejectConfirmedSmsNotes(copied)" in privacy,
            "plaintext legacy SMS protection missing")
    require("automaticallyActivateSqlCipher => false" in release,
            "SQLCipher must stay inactive until production attestation")
    require("M226" in notes and "SQLCipher" in notes, "release notes not updated")
    require("python3 scripts/m147_main_merge_readiness_audit.py" in workflow and
            "python3 scripts/qa/m226_m206_main_reconciliation_review.py" in workflow,
            "M224 audit cannot be removed or M226 review bypassed")

    report = {
        "audit": "M226-two-parent-M206-reconciliation",
        "main_sha": current_main,
        "m206_source_sha": M206_HEAD,
        "merge_sha": merge,
        "reviewed_head_sha": head,
        "changed_paths": sorted(changed),
        "status": "EXACT_MAIN_SOURCE_SCOPE_ONLY",
        "main_code_preserved_on_conflicts": True,
        "legacy_sms_plaintext_storage_allowed": False,
        "sqlcipher_production_approved": False,
        "physical_device_ui_passed": False,
        "release_approved": False,
    }
    path = Path("build/m147-final-review-report.json")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2, ensure_ascii=False))

if __name__ == "__main__":
    main()
