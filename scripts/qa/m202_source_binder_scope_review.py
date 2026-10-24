#!/usr/bin/env python3
"""Fail-closed exact-SHA review for an Android emulator-only SQLCipher test."""
import json
import os
import subprocess
from pathlib import Path

EXPECTED = {
    ".github/scripts/run-m202-sqlcipher-binder-android.sh",
    ".github/workflows/m147-final-main-review-gate.yml",
    ".github/workflows/m202-android-sqlcipher-source-binder-dryrun.yml",
    "docs/qa/m202-sqlcipher-android-binder-dryrun.md",
    "integration_test/m202_home_widget_source_binder_android_test.dart",
    "scripts/qa/m202_source_binder_scope_review.py",
}


def git(*args):
    return subprocess.run(
        ["git", *args], check=True, capture_output=True, text=True,
    ).stdout.strip()


def must(ok, why):
    if not ok:
        raise SystemExit("M202 BLOCKED: " + why)


def main():
    sha = git("rev-parse", "HEAD")
    must(os.environ.get("REVIEW_HEAD_SHA", "").strip() == sha,
         "reviewed SHA mismatch")
    base = git("rev-parse", "refs/remotes/origin/main")
    must(git("merge-base", base, sha) == base,
         "main advanced; rebase and rerun all tests")
    changed = set(filter(None, git("diff", "--name-only", base, sha).splitlines()))
    must(changed == EXPECTED, "file scope mismatch: " +
         repr(sorted(changed ^ EXPECTED)))

    t = Path("integration_test/m202_home_widget_source_binder_android_test.dart").read_text()
    w = Path(".github/workflows/m202-android-sqlcipher-source-binder-dryrun.yml").read_text()
    sh = Path(".github/scripts/run-m202-sqlcipher-binder-android.sh").read_text()
    doc = Path("docs/qa/m202-sqlcipher-android-binder-dryrun.md").read_text()
    source = Path("lib/storage/waffra_production_finance_source_guard.dart").read_text()
    release = Path("lib/storage/waffra_production_cutover_release_gate.dart").read_text()
    binder = Path("lib/storage/waffra_production_finance_authority_binding.dart").read_text()

    for marker in (
        "IntegrationTestWidgetsFlutterBinding.ensureInitialized()",
        "WaffraProductionFinanceAuthorityBinding.bind(",
        "WaffraFinanceRoute.widgetStartup",
        "WaffraFinanceRoute.widgetSmsConfirmedSave",
        "WaffraFinanceRoute.appStartup",
        "WaffraFinanceRoute.dashboardRead",
        "commitConfirmedSms(",
        "incorrect-test-only-key",
        "expect(await dbFile.length(), sizeBefore)",
        "await widget.close()",
        "await home.close()",
        "finally",
        "SharedPreferences.setMockInitialValues",
    ):
        must(marker in t, "missing Android runtime source test: " + marker)

    for marker in (
        "reactivecircus/android-emulator-runner@v2",
        "m202_home_widget_source_binder_android_test.dart",
        "bash .github/scripts/run-m202-sqlcipher-binder-android.sh",
        "ANDROID_EMULATOR_QA_ONLY_NO_GO",
        '"live_production_routes_attested": 0',
        '"physical_phones_attested": 0',
        '"sqlcipher_production_activated": False',
    ):
        must(marker in w, "missing enforceable emulator proof: " + marker)
    for marker in (
        "set -euo pipefail", "run_check",
        "m202_home_widget_source_binder_android_test.dart",
        "live_finance_migration_receipts_android_test.dart",
        "m120_verified_receipt_reopen_android_test.dart",
        "portable_encrypted_receipts_android_test.dart",
        "M202_EMULATOR_QA_PASS",
    ):
        must(marker in sh, "runner could mask a failed test: " + marker)
    for marker in ("NO-GO", "24 live finance routes", "physical phones",
                   "test-only injection", "release-signed"):
        must(marker in doc, "missing release limitation: " + marker)
    must("all_live_writers_not_yet_routed" in source,
         "source guard has been disabled")
    must("bool get automaticallyActivateSqlCipher => false;" in release,
         "production cutover was enabled")
    must("sourceGuard.inspect()" in binder, "source binder safety weakened")

    report = {
        "reviewed_head": sha,
        "base_main": base,
        "changed_files": sorted(changed),
        "android_emulator_executed_by_this_scope_review": False,
        "production_24_route_evidence_count": 0,
        "physical_device_attestation_count": 0,
        "production_sqlcipher_activated": False,
        "status": "EXACT_SHA_EMULATOR_TEST_SCOPE_ONLY_NO_GO",
    }
    out = Path("build/m147-final-review-report.json")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
