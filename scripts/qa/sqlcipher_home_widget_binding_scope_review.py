#!/usr/bin/env python3
"""Exact-HEAD review of actual Home/Widget SQLCipher source wiring (NO-GO)."""
import json
import os
import subprocess
from pathlib import Path

FILES = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/sqlcipher-home-widget-authority-binding.md",
    "lib/main.dart",
    "lib/waffra_widget_capture.part.dart",
    "lib/storage/waffra_production_finance_authority_binding.dart",
    "test/storage/production_finance_authority_binding_test.dart",
    "test/m108_home_widget_one_finance_writer_test.dart",
    "scripts/qa/sqlcipher_home_widget_binding_scope_review.py",
}


def git(*args):
    return subprocess.run(["git", *args], check=True,
                          capture_output=True, text=True).stdout.strip()


def main():
    head = git("rev-parse", "HEAD")
    if head != os.environ.get("REVIEW_HEAD_SHA", "").strip():
        raise SystemExit("BINDING BLOCKED: absent or stale exact SHA")
    base = git("rev-parse", "refs/remotes/origin/main")
    if git("merge-base", base, head) != base:
        raise SystemExit("BINDING BLOCKED: main moved; rebase first")
    changed = set(filter(None, git("diff", "--name-only", base, head).splitlines()))
    if changed != FILES:
        raise SystemExit("BINDING BLOCKED: unreviewed file scope " +
                         repr(sorted(changed ^ FILES)))

    home = Path("lib/main.dart").read_text()
    widget = Path("lib/waffra_widget_capture.part.dart").read_text()
    binding = Path(
        "lib/storage/waffra_production_finance_authority_binding.dart"
    ).read_text()
    tests = Path(
        "test/storage/production_finance_authority_binding_test.dart"
    ).read_text()
    release = Path(
        "lib/storage/waffra_production_cutover_release_gate.dart"
    ).read_text()
    source = Path(
        "lib/storage/waffra_production_finance_source_guard.dart"
    ).read_text()
    for marker in (
        "await _ensureFinanceBound();",
        "WaffraProductionFinanceAuthorityBinding.bind(",
        "WaffraFinanceRoute.appStartup",
        "if(binding!=null)unawaited(_financialWriteQueue.drain().whenComplete(binding.close));",
    ):
        if marker not in home:
            raise SystemExit("BINDING BLOCKED: Home does not bind " + marker)
    for marker in (
        "WaffraProductionFinanceAuthorityBinding.bind(",
        "WaffraFinanceRoute.widgetStartup",
        "_financeBinding?.authority",
        "if(binding!=null){",
        "pending.whenComplete(binding.close)",
    ):
        if marker not in widget:
            raise SystemExit("BINDING BLOCKED: widget does not bind " + marker)
    for marker in (
        "sourceGuard.inspect()",
        "WaffraProductionFinanceSource.manualRecoveryRequired",
        "WaffraProductionFinanceSource.guardedLegacy",
        "if (evidence == null)",
        "FileSystemEntity.type(path.path, followLinks: false)",
        "WaffraEncryptedStore.openAt(path, key: key)",
        "WaffraEncryptedFinanceSession(",
        "WaffraVerifiedEncryptedFinanceBridge(",
        "await authority.load(route: startupRoute)",
        "await store.close()",
    ):
        if marker not in binding:
            raise SystemExit("BINDING BLOCKED: missing runtime proof " + marker)
    for forbidden in (
        "openShadow(", "initializeEmpty(", "setBool(", "setString(",
        "WaffraEncryptedStore.openShadow(", "write(key:", "automaticallyActivateSqlCipher = true",
    ):
        if forbidden in binding:
            raise SystemExit("BINDING BLOCKED: runtime may mutate source " + forbidden)
    for marker in (
        "manual-recovery source never falls through to legacy",
        "an existing encrypted source cannot launch without release evidence",
        "fake green evidence cannot invent missing encrypted database",
        "an encrypted approval cannot silently downgrade to legacy",
    ):
        if marker not in tests:
            raise SystemExit("BINDING BLOCKED: negative test missing " + marker)
    if "all_live_writers_not_yet_routed" not in source:
        raise SystemExit("BINDING BLOCKED: source guard weakened")
    if "bool get automaticallyActivateSqlCipher => false;" not in release:
        raise SystemExit("BINDING BLOCKED: automatic cutover was unlocked")

    report = {
        "reviewed_head_sha": head,
        "main_sha": base,
        "changed_files": sorted(changed),
        "verified_signed_device_count": 0,
        "certified_runtime_finance_routes": 0,
        "sqlcipher_live_user_activation": False,
        "production_release_approved": False,
        "status": "SOURCE_WIRING_REVIEWED_CI_ONLY_PRODUCTION_NO_GO",
    }
    out = Path("build/m147-final-review-report.json")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
