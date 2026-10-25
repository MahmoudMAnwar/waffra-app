#!/usr/bin/env python3
"""M212 exact-head multi-track QA guard; never claims production readiness."""
import json
import os
import subprocess
from pathlib import Path

EXPECTED = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/m212-parallel-sqlcipher-production-readiness.md",
    "docs/release/WAFFRA_APPROVED_CHANGES.txt",
    "lib/storage/waffra_encrypted_full_finance_reset.dart",
    "lib/storage/waffra_encrypted_finance_session.dart",
    "lib/storage/waffra_verified_encrypted_finance_bridge.dart",
    "lib/storage/waffra_verified_finance_authority.dart",
    "scripts/qa/m212_parallel_cutover_scope_review.py",
    "test/storage/m188_encrypted_full_finance_reset_test.dart",
    "test/storage/m212_cutover_interruption_recovery_test.dart",
    "test/storage/m212_full_finance_reset_route_gate_test.dart",
}

def git(*args):
    return subprocess.run(["git", *args], check=True,
                          capture_output=True, text=True).stdout.strip()

def require(condition, description):
    if not condition:
        raise SystemExit("M212 BLOCKED: " + description)

def read(path):
    return Path(path).read_text(encoding="utf-8")

def main():
    sha=git("rev-parse", "HEAD")
    main=git("rev-parse", "refs/remotes/origin/main")
    require(sha == os.environ.get("REVIEW_HEAD_SHA", "").strip(),
            "checked-out SHA differs from reviewed PR head")
    require(git("merge-base", main, sha) == main,
            "PR isn't based on current main; reconcile before review")
    changed=set(filter(None,git("diff","--name-only",main,sha).splitlines()))
    require(changed == EXPECTED,
            "unexpected modified paths: " + repr(sorted(changed ^ EXPECTED)))
    route=read("lib/storage/waffra_production_finance_routing_gate.dart")
    auth=read("lib/storage/waffra_verified_finance_authority.dart")
    bridge=read("lib/storage/waffra_verified_encrypted_finance_bridge.dart")
    session=read("lib/storage/waffra_encrypted_finance_session.dart")
    reset=read("lib/storage/waffra_encrypted_full_finance_reset.dart")
    reset_test=read("test/storage/m212_full_finance_reset_route_gate_test.dart")
    recovery=read("test/storage/m212_cutover_interruption_recovery_test.dart")
    m188=read("test/storage/m188_encrypted_full_finance_reset_test.dart")
    physical=read("scripts/qa/m189_physical_device_source_probe.py")
    old_source=read("lib/storage/waffra_production_finance_source_guard.dart")
    release=read("lib/storage/waffra_production_cutover_release_gate.dart")
    workflow=read(".github/workflows/android.yml")
    review=read(".github/workflows/m147-final-main-review-gate.yml")
    notes=read("docs/release/WAFFRA_APPROVED_CHANGES.txt")
    guide=read("docs/qa/m212-parallel-sqlcipher-production-readiness.md")

    names=route.split("enum WaffraFinanceRoute {",1)[1].split("}",1)[0]
    routes=[x.strip().rstrip(",") for x in names.splitlines()
            if x.strip() and not x.lstrip().startswith("//")]
    require(len(routes) == 24 and len(set(routes)) == 24 and
            "fullFinanceReset" in routes and "backupRestore" in routes,
            "the 24 financial paths were changed or hidden")
    for marker in (
        "resetVerifiedFinance({", "WaffraFinanceRoute.fullFinanceReset",
        "WaffraRuntimeFinanceBackend.verifiedEncrypted",
        "encryptedBackup:", "biometricVerified:", "externalBackupSaved:",
    ):
        require(marker in auth, "source-authority reset route missing: "+marker)
    for module in (bridge,session):
        require("resetVerifiedFinance({" in module and
                "WaffraEncryptedFullResetResult" in module,
                "reset must pass through encrypted session and bridge")
    require("verifySourceUnderLock: _requireActivatedUnderLock" in bridge,
            "reset bypasses the native source witness")
    require("'fresh_finance_cutover_checkpoint'" in reset and
            "fresh_finance_cutover_checkpoint" not in
            reset.split("static const _erasedTables = <String>[",1)[1].
                 split("];",1)[0],
            "full reset could delete the activation certificate")
    for marker in (
        "M212 fullFinanceReset cannot erase legacy money",
        "M212 pending SQLCipher activation fails closed",
        "M212 all 24 finance routes remain unverified",
    ):
        require(marker in reset_test, "negative tests missing: "+marker)
    for marker in (
        "M212 interrupted prepared stage",
        "M212 interrupted verified stage",
        "M212 active SQL witness without external pointer",
        "coldReopen()",
    ):
        require(marker in recovery, "crash simulation missing: "+marker)
    require("M212 reset preserves preexisting encrypted activation checkpoint" in m188,
            "positive reset checkpoint preservation test missing")
    require("Exactly two distinct online" in physical and
            "hardware_detected" in physical and
            '"source_cutover_attested": False' in physical,
            "two real-device evidence cannot be forged in CI")
    require("bool get automaticallyActivateSqlCipher => false;" in release and
            "all_live_writers_not_yet_routed" in old_source,
            "unsafe automatic SQLCipher production activation change")
    require("M212 SHA-pinned" in review and
            "m212_parallel_cutover_scope_review.py" in review,
            "M212 exact-head review is not required")
    for marker in (
        "branches:", "      - main", "Full mandatory Flutter and Python test suite",
        "Check every independent test workflow on this exact SHA",
        "Gate QA APK on embedded SHA and current branch head",
        "Publish signed QA APK (FINAL step)",
        "Waffra-Android-ARM64-Release-",
    ):
        require(marker in workflow, "missing existing main APK QA gate: "+marker)
    for marker in ("[20] M210", "[21] M211", "[22] M212",
                   "SQLCipher", "المرفقات", "الوضع الفاتح"):
        require(marker in notes, "approved change notes weren't refreshed: "+marker)
    require("production NO-GO" in guide and
            "two physical" in guide and "24 independent" in guide,
            "QA vs physical-device status is not clearly documented")
    report={
        "milestone":"M212",
        "head":sha,
        "base":main,
        "scope_files":sorted(changed),
        "route_inventory":len(routes),
        "route_connections_this_pr":["fullFinanceReset"],
        "CI_route_runtime": "FLUTTER_TEST_REQUIRED",
        "crash_restart_witness": "FLUTTER_TEST_REQUIRED",
        "physical_phones_verified":0,
        "actual_live_routes_proven":0,
        "active_SQLCipher_customer_source":False,
        "source_marker_modified":False,
        "main_QA_APK_on_merge": "PUSH_CI_REQUIRED",
        "production_release":"NO_GO",
    }
    target=Path("build/m147-final-review-report.json")
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(report))

if __name__=="__main__":
    main()
