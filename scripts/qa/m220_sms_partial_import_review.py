#!/usr/bin/env python3
"""M220 exact-head SMS failure recovery/privacy review (release NO-GO)."""
import json
import os
import subprocess
from pathlib import Path

SCOPE = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/m220-sms-partial-save-review-without-plaintext.md",
    "docs/release/WAFFRA_APPROVED_CHANGES.txt",
    "lib/main.dart",
    "lib/storage/waffra_sms_partial_save_recovery.dart",
    "scripts/qa/m220_sms_partial_import_review.py",
    "test/storage/m220_sms_partial_save_recovery_test.dart",
}

def git(*args):
    return subprocess.run(["git", *args], check=True,
                          capture_output=True, text=True).stdout.strip()

def require(ok, reason):
    if not ok:
        raise SystemExit("M220 BLOCKED: " + reason)

def read(path):
    return Path(path).read_text(encoding="utf-8")

def main():
    head = git("rev-parse", "HEAD")
    base = git("rev-parse", "refs/remotes/origin/main")
    require(head == os.environ.get("REVIEW_HEAD_SHA", "").strip(),
            "expected PR head differs from tested checkout")
    require(git("merge-base", base, head) == base,
            "review branch is not based on current main")
    paths = set(filter(None, git("diff", "--name-only", base, head).splitlines()))
    require(paths == SCOPE, "unapproved diff: " + repr(sorted(paths ^ SCOPE)))

    app = read("lib/main.dart")
    checker = read("lib/storage/waffra_sms_partial_save_recovery.dart")
    tests = read("test/storage/m220_sms_partial_save_recovery_test.dart")
    workflow = read(".github/workflows/m147-final-main-review-gate.yml")
    notes = read("docs/release/WAFFRA_APPROVED_CHANGES.txt")
    qa = read("docs/qa/m220-sms-partial-save-review-without-plaintext.md")
    gate = read("lib/storage/waffra_production_cutover_release_gate.dart")
    finance = read("lib/storage/waffra_verified_finance_authority.dart")

    for marker in (
        "import 'storage/waffra_sms_partial_save_recovery.dart';",
        "WaffraSmsPartialSaveRecovery.reconcile(",
        "proposedSourceIndexes",
        "persistedIds:{for(final e in persisted)e.id}",
        "if(recovery.saved!=applied.saved)",
        "rejectedMessages=[for(final item in recovery.unsaved)item.message]",
        "if(reviewMissing==true&&recovery.unsaved.isNotEmpty)",
        "reviewing=true;",
        "await prepare(0,update)",
        "description.text=result.title;",
        "مراجعة ${recovery.unsaved.length} غير محفوظة",
        "تخطي المكررة",
        "تم حفظ جزء من المعاملات",
    ):
        require(marker in app, "missing user-visible SMS recovery: " + marker)

    for marker in (
        "enum WaffraSmsNotSavedReason",
        "amountUnrecognized",
        "categoryUnresolved",
        "alreadySaved",
        "persistedIds.contains(proposedIds[i])",
        "saved + missed.length != discovered.length",
        "List<WaffraSmsNotSavedMessage>.unmodifiable(missed)",
    ):
        require(marker in checker, "missing exact saved/unsaved parity: " + marker)
    for marker in (
        "M220 56 saved and 13 not saved remain exactly reviewable",
        "M220 writer-skipped duplicate has original source and reason",
        "M220 user-skipped duplicate remains a review option",
        "M220 refuses to hide unaccounted bank messages",
        "M220 refuses overlapping rejected and proposed source",
        "M220 refuses duplicate candidate IDs",
        "M220 rejects over 100 messages rather than silently truncating",
        "M220 complete durable commit produces no retry list",
    ):
        require(marker in tests, "missing negative test: " + marker)
    require("M220 SHA-pinned" in workflow and
            "m220_sms_partial_import_review.py" in workflow,
            "missing exact-SHA review")
    require("[30] M220" in notes, "release note missing")
    require("production NO-GO" in qa and
            "69 = 56 saved + 13 rejected" in qa and
            "No SharedPreferences" in qa, "privacy/production blockers missing")
    require("bool get automaticallyActivateSqlCipher => false;" in gate,
            "unsafe automatic source switch")
    require("originalSmsNotesOmittedOnLegacy" in finance and
            "Map<String, Object?>.unmodifiable({...record, 'notes': ''})"
            in finance, "legacy raw SMS privacy enforcement changed")
    require("prefs.setString('entries'" not in checker and
            "package:shared_preferences" not in checker,
            "recovery must never persist SMS plaintext")

    out = Path("build/m147-final-review-report.json")
    out.parent.mkdir(parents=True, exist_ok=True)
    report = {
        "milestone": "M220",
        "reviewed_head": head,
        "main_at_review": base,
        "paths": sorted(paths),
        "recover_unsaved_in_memory_only": True,
        "legacy_sms_plaintext_stored": False,
        "all_finance_routes_production_verified": False,
        "android_devices_verified": 0,
        "production": "NO_GO",
    }
    out.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))

if __name__ == "__main__":
    main()
