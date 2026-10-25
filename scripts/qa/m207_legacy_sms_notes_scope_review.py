#!/usr/bin/env python3
"""M207 exact-SHA privacy guard review; no SQLCipher production approval."""
import json
import os
from pathlib import Path
import subprocess

EXPECTED = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/m207-legacy-sms-notes-privacy-no-go.md",
    "lib/storage/waffra_home_finance_persistence.dart",
    "scripts/qa/m207_legacy_sms_notes_scope_review.py",
    "test/storage/m207_legacy_sms_notes_privacy_test.dart",
}


def git(*args):
    return subprocess.run(["git", *args], check=True, capture_output=True,
                          text=True).stdout.strip()


def require(condition, message):
    if not condition:
        raise SystemExit("M207 PRIVACY NO-GO: " + message)


def main():
    head = git("rev-parse", "HEAD")
    require(head == os.environ.get("REVIEW_HEAD_SHA", "").strip(),
            "exact HEAD SHA mismatch")
    base = git("rev-parse", "refs/remotes/origin/main")
    require(git("merge-base", base, head) == base,
            "main moved; rebase and retest before review")
    changed = set(filter(None, git("diff", "--name-only", base, head).splitlines()))
    require(changed == EXPECTED, "unexpected file scope " +
            repr(sorted(changed ^ EXPECTED)))

    source = Path("lib/storage/waffra_home_finance_persistence.dart").read_text()
    tests = Path("test/storage/m207_legacy_sms_notes_privacy_test.dart").read_text()
    docs = Path("docs/qa/m207-legacy-sms-notes-privacy-no-go.md").read_text()
    workflow = Path(".github/workflows/m147-final-main-review-gate.yml").read_text()
    release = Path("lib/storage/waffra_production_cutover_release_gate.dart").read_text()
    source_guard = Path("lib/storage/waffra_production_finance_source_guard.dart").read_text()

    for marker in (
        "class WaffraLegacySmsNotesPrivacyGate",
        "rejectConfirmedSmsNotes(copied)",
        "rejectNewOrModifiedSmsNotes(",
        "previousLedger: preferences.getString('entries')",
        "prior?['sourceType'] == 'sms'",
        "Original bank SMS source cannot be downgraded in legacy storage.",
        "Original bank SMS notes require verified encrypted storage.",
    ):
        require(marker in source, "missing writer privacy guard " + marker)
    for marker in (
        "confirmed Home or Widget SMS raw notes fail",
        "confirmed SMS without original notes still saves",
        "dashboard batch cannot introduce plaintext notes",
        "existing SMS notes are preserved",
        "disguising it as manual is blocked",
        "two-save SMS source downgrade is blocked",
        "manual transaction notes remain allowed",
    ):
        require(marker in tests, "missing regression " + marker)
    require("NO-GO" in docs and "SharedPreferences" in docs and
            "Google Play remains the" in docs, "privacy disclaimer missing")
    require("python3 scripts/qa/m207_legacy_sms_notes_scope_review.py" in workflow,
            "M147 strict M207 review step missing")
    require("bool get automaticallyActivateSqlCipher => false;" in release,
            "SQLCipher release gate changed")
    require("all_live_writers_not_yet_routed" in source_guard,
            "source guard weakened")

    output = Path("build/m147-final-review-report.json")
    output.parent.mkdir(parents=True, exist_ok=True)
    report = {
        "milestone": "M207",
        "reviewed_sha": head,
        "base_main": base,
        "files": sorted(changed),
        "legacy_sms_notes_write_guard_reviewed": True,
        "encrypted_notes_production_certified": False,
        "physical_android_devices_verified": False,
        "live_routes_24_of_24_verified": False,
        "google_play_publication_permitted": False,
        "status": "M207_LEGACY_SMS_PRIVACY_GUARD_RELEASE_NO_GO",
    }
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
