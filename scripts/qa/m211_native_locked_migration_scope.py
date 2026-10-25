#!/usr/bin/env python3
"""Exact-SHA cross-engine encrypted migration staging; production NO-GO."""
import json
import os
import subprocess
from pathlib import Path

APPROVED = {
    "lib/storage/waffra_migration_coordinator.dart",
    "test/storage/migration_coordinator_test.dart",
    ".github/workflows/m147-final-main-review-gate.yml",
    "scripts/qa/m211_native_locked_migration_scope.py",
    "docs/qa/m211-native-legacy-migration-staging.md",
}
def git(*args):
    return subprocess.run(["git", *args], check=True,
                          capture_output=True, text=True).stdout.strip()
def require(value, label):
    if not value:
        raise SystemExit("M211 BLOCKED: " + label)
def main():
    sha = git("rev-parse", "HEAD")
    main_sha = git("rev-parse", "refs/remotes/origin/main")
    require(sha == os.environ.get("REVIEW_HEAD_SHA", "").strip(),
            "reviewed SHA differs from exact checkout")
    require(git("merge-base", main_sha, sha) == main_sha,
            "main advanced; reconcile and rerun")
    changed = set(filter(None, git("diff", "--name-only",
                                   main_sha, sha).splitlines()))
    require(changed == APPROVED, "unexpected change scope: " +
            repr(sorted(changed ^ APPROVED)))
    coordinator = Path("lib/storage/waffra_migration_coordinator.dart").read_text()
    tests = Path("test/storage/migration_coordinator_test.dart").read_text()
    m147 = Path(".github/workflows/m147-final-main-review-gate.yml").read_text()
    legacy = Path("lib/storage/waffra_legacy_finance_writer_coordinator.dart").read_text()
    guard = Path("lib/storage/waffra_production_finance_source_guard.dart").read_text()
    release = Path("lib/storage/waffra_production_cutover_release_gate.dart").read_text()
    doc = Path("docs/qa/m211-native-legacy-migration-staging.md").read_text()
    for marker in (
        "stageWithSharedWriterLease(", "legacyWriter.withCurrentPreferences(",
        "copyCurrentFinancialPreferences(current)", "await prefs.reload();",
        "stageSnapshot(vaultId, snapshot)",
        "Shadow-to-relational financial parity mismatch.",
        "await database?.close();",
    ):
        require(marker in coordinator, "native staged-snapshot fence missing: " + marker)
    for marker in (
        "M211 native Home/Widget lock stages an exact historical SMS note safely",
        "M211 native migration lease refuses active source marker before opening DB",
        "M211 finance snapshot copy is immutable",
        "legacy-original-note", "WaffraLiveLegacyFinanceGuard.activeKey",
    ):
        require(marker in tests, "missing negative native lock QA: " + marker)
    require("WaffraExperimentalWriterGate(" in legacy and
            "requireLegacySource(prefs)" in legacy and
            "const WaffraLegacyWidgetCommitJournal().recover(prefs)" in legacy,
            "shared production writer lock or crash journal was bypassed")
    require("all_live_writers_not_yet_routed" in guard,
            "production guarded source was modified")
    require("bool get automaticallyActivateSqlCipher => false;" in release,
            "production auto-activation was enabled")
    require("M211" in m147 and "m211_native_locked_migration_scope.py" in m147,
            "no exact-SHA CI review")
    require("NO-GO" in doc and "receipts" in doc and
            "physical" in doc and "24" in doc, "missing release blockers")
    report = {
        "milestone": "M211",
        "checked_head": sha,
        "main_base": main_sha,
        "changed_files": sorted(changed),
        "shared_legacy_writer_lock": "TEST_REQUIRED",
        "encrypted_legacy_staging": "TEST_REQUIRED",
        "source_markers_changed": False,
        "user_data_migrated": False,
        "production_sqlcipher_active": False,
        "physical_devices_proven": 0,
        "status": "NATIVE_LEASE_MIGRATION_STAGING_ONLY_NO_GO",
    }
    target = Path("build/m147-final-review-report.json")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report))
if __name__ == "__main__":
    main()
