#!/usr/bin/env python3
"""Exact-SHA review of approved UI corrections; no finance logic changed."""
import json
import os
import subprocess
from pathlib import Path

EXPECTED = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "lib/main.dart",
    "scripts/qa/waffra_directional_fab_receipt_scope_review.py",
    "test/m127_ui_tour_backup_acceptance_test.dart",
    "test/waffra_approved_ui_batch_test.dart",
    "test/waffra_directional_fab_receipt_corner_test.dart",
}


def git(*args):
    return subprocess.run(
        ["git", *args], check=True, text=True, capture_output=True
    ).stdout.strip()


def main():
    head = git("rev-parse", "HEAD")
    base = git("rev-parse", "refs/remotes/origin/main")
    if not os.environ.get("REVIEW_HEAD_SHA") == head:
        raise SystemExit("UI BLOCKED: reviewed SHA mismatch")
    if git("merge-base", base, head) != base:
        raise SystemExit("UI BLOCKED: branch must be rebased on latest main")
    changed = set(filter(None, git("diff", "--name-only", base, head).splitlines()))
    if changed != EXPECTED:
        raise SystemExit("UI BLOCKED: unexpected changed files " +
                         repr(sorted(changed ^ EXPECTED)))
    app = Path("lib/main.dart").read_text()
    tests = Path("test/waffra_directional_fab_receipt_corner_test.dart").read_text()
    for marker in (
        "WaffraDirectionalFabLocation(english:waffraIsEnglish)",
        "scaffoldWidth-fabWidth-rightInset-16",
        "16+leftInset",
        "waffraIsEnglish?CrossAxisAlignment.end:CrossAxisAlignment.start",
        "WaffraReceiptCornerBadge(count:attachmentCount,english:waffraIsEnglish)",
        "if(attachmentCount>0)PositionedDirectional(top:0,end:0",
        "child:WaffraReceiptCornerBadge",
        "WaffraReceiptCornerClipper",
        "onTap:()=>showReceipt(e.receiptPath!)",
    ):
        if marker not in app:
            raise SystemExit("UI BLOCKED: approved FAB/corner behavior missing " + marker)
    if "class WaffraPhysicalLeftFab " in app:
        raise SystemExit("UI BLOCKED: old unconditional left anchor still used")
    for marker in (
        "English plus physically RIGHT, Arabic plus physically LEFT",
        "plus respects both physical system insets",
        "receipt count is INSIDE a clipped corner marker",
    ):
        if marker not in tests:
            raise SystemExit("UI BLOCKED: essential regression missing " + marker)
    for term in (
        "lib/storage/", "android/", "pubspec.yaml", "firestore.rules",
    ):
        if any(x.startswith(term) for x in changed):
            raise SystemExit("UI BLOCKED: approved UI patch must not edit production data")
    release = Path("lib/storage/waffra_production_cutover_release_gate.dart").read_text()
    if "bool get automaticallyActivateSqlCipher => false;" not in release:
        raise SystemExit("UI BLOCKED: production encryption gate changed")
    out = Path("build/m147-final-review-report.json")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps({
        "head_sha": head,
        "base_sha": base,
        "changed_files": sorted(changed),
        "fixed_arabic_plus": "physical left",
        "fixed_english_plus": "physical right",
        "attachment_counter": "inside directional corner flag",
        "source_activation_changed": False,
        "signed_device_ui_verified": False,
        "status": "UI_SCOPE_REVIEW_ONLY_PENDING_CI_AND_DEVICE_QA",
    }, indent=2) + "\n")
    print("UI approved directional FAB + receipt corner SHA-pinned scope verified")


if __name__ == "__main__":
    main()
