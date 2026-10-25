#!/usr/bin/env python3
"""M210: exact-SHA security review; no inference of a production cutover."""
import json
import os
import subprocess
from pathlib import Path

EXPECTED = {
    "lib/storage/waffra_unified_finance_writer.dart",
    "test/storage/unified_finance_writer_test.dart",
    "integration_test/m202_home_widget_source_binder_android_test.dart",
    ".github/workflows/m147-final-main-review-gate.yml",
    ".github/workflows/m202-android-sqlcipher-source-binder-dryrun.yml",
    "scripts/qa/m210_encrypted_sms_notes_scope_review.py",
    "docs/qa/m210-encrypted-sms-notes-qa.md",
}

def git(*args):
    return subprocess.run(["git", *args], check=True,
                          capture_output=True, text=True).stdout.strip()

def require(ok, label):
    if not ok:
        raise SystemExit("M210 REVIEW BLOCKED: " + label)

def main():
    head = git("rev-parse", "HEAD")
    require(head == os.environ.get("REVIEW_HEAD_SHA", "").strip(),
            "checked-out commit does not match reviewed head")
    main_head = git("rev-parse", "refs/remotes/origin/main")
    require(git("merge-base", main_head, head) == main_head,
            "main moved; reconcile and test again")
    files = set(filter(None, git("diff", "--name-only", main_head, head).splitlines()))
    require(files == EXPECTED, "unreviewed files: " + repr(sorted(files ^ EXPECTED)))

    writer = Path("lib/storage/waffra_unified_finance_writer.dart").read_text()
    suite = Path("test/storage/unified_finance_writer_test.dart").read_text()
    android = Path("integration_test/m202_home_widget_source_binder_android_test.dart").read_text()
    workflow = Path(".github/workflows/m202-android-sqlcipher-source-binder-dryrun.yml").read_text()
    m147 = Path(".github/workflows/m147-final-main-review-gate.yml").read_text()
    release = Path("lib/storage/waffra_production_cutover_release_gate.dart").read_text()
    source = Path("lib/storage/waffra_production_finance_source_guard.dart").read_text()
    binder = Path("lib/storage/waffra_production_finance_authority_binding.dart").read_text()
    legacy = Path("lib/storage/waffra_home_finance_persistence.dart").read_text()
    doc = Path("docs/qa/m210-encrypted-sms-notes-qa.md").read_text()
    for marker in (
        "newlySavedSmsNotes", "Encrypted SMS original note parity failed.",
        "SELECT entry_id,source_json FROM fresh_finance_entries",
        "final written = await snapshot.commit(",
        "snapshot.store.transaction(() async",
    ):
        require(marker in writer, "encrypted atomic original-note witness missing: " + marker)
    for marker in (
        "M210 encrypted-only original SMS notes remain byte-exact after cold reopen",
        "M210 SQL projection note corruption rolls back transaction and SMS hash",
        "CREATE TRIGGER m210_damage_sms_note",
        "await vault.close()",
    ):
        require(marker in suite, "SQL rollback/reopen QA missing: " + marker)
    for marker in (
        "originalWidgetSms", "originalHomeSms",
        "WaffraFinanceRoute.widgetSmsConfirmedSave",
        "WaffraFinanceRoute.bulkSmsConfirmedSave",
        "originalSmsNotesOmittedOnLegacy, isFalse",
        "incorrect-test-only-key",
        "SharedPreferences.setMockInitialValues",
        "SELECT source_json FROM fresh_finance_entries WHERE entry_id=?",
    ):
        require(marker in android, "Android SQLCipher note evidence missing: " + marker)
    require("reactivecircus/android-emulator-runner@v2" in workflow,
            "actual Android emulator check removed")
    require("original_bank_sms_notes_roundtrip" in workflow,
            "emulator evidence does not mention encrypted original notes")
    require("M210" in m147 and "m210_encrypted_sms_notes_scope_review.py" in m147,
            "new scope not connected to exact SHA reviewer")
    require("bool get automaticallyActivateSqlCipher => false;" in release,
            "production activation was modified")
    require("all_live_writers_not_yet_routed" in source,
            "legacy source fail-closed marker disappeared")
    require("WaffraLegacySmsNotesPrivacyGate.rejectConfirmedSmsNotes(copied)" in legacy,
            "plaintext bank SMS guard is missing")
    require("sourceGuard.inspect()" in binder and
            "Existing SQLCipher source cannot start without verified release evidence." in binder,
            "existing source binder approval requirement missing")
    require("NO-GO" in doc and "two physical" in doc and "24" in doc,
            "actual release blockers not documented")
    report = {
        "milestone": "M210",
        "source_sha": head,
        "base_sha": main_head,
        "files": sorted(files),
        "scope_review": "PASS",
        "sms_original_text_encrypted_roundtrip": "ANDROID_TEST_REQUIRED",
        "physical_devices_verified": 0,
        "production_routes_certified": 0,
        "sqlcipher_production_activated": False,
        "status": "ENCRYPTED_SMS_INTEGRITY_QA_ONLY_NO_GO"
    }
    output = Path("build/m147-final-review-report.json")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report))

if __name__ == "__main__":
    main()
