#!/usr/bin/env python3
"""Review exactly the M180 source-witnessed SQLCipher custom goals diff."""
from __future__ import annotations
import json
import os
import subprocess
from pathlib import Path

EXPECTED = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/m180-verified-encrypted-custom-goals.md",
    "lib/storage/waffra_fresh_encrypted_vault_bootstrap.dart",
    "lib/storage/waffra_encrypted_finance_session.dart",
    "lib/storage/waffra_verified_encrypted_finance_bridge.dart",
    "lib/storage/waffra_verified_finance_authority.dart",
    "scripts/qa/m180_encrypted_custom_goals_scope.py",
    "test/storage/m180_encrypted_custom_goal_suggestions_test.dart",
}

def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], check=True, capture_output=True, text=True,
    ).stdout.strip()

def inspect() -> None:
    head = git("rev-parse", "HEAD")
    expected = os.environ.get("REVIEW_HEAD_SHA", "").strip()
    if not expected or expected != head:
        raise SystemExit("M180: exact PR head SHA review required")
    base = git("rev-parse", "refs/remotes/origin/main")
    if git("merge-base", base, head) != base:
        raise SystemExit("M180: base main has moved or branch diverged")
    changed = set(filter(None, git(
        "diff", "--name-only", base, head,
    ).splitlines()))
    if changed != EXPECTED:
        raise SystemExit("M180: changed file scope mismatch "
                         + repr(sorted(changed ^ EXPECTED)))
    bridge = Path("lib/storage/waffra_verified_encrypted_finance_bridge.dart").read_text()
    authority = Path("lib/storage/waffra_verified_finance_authority.dart").read_text()
    session = Path("lib/storage/waffra_encrypted_finance_session.dart").read_text()
    bootstrap = Path("lib/storage/waffra_fresh_encrypted_vault_bootstrap.dart").read_text()
    source_guard = Path("lib/storage/waffra_production_finance_source_guard.dart").read_text()
    release = Path("lib/storage/waffra_production_cutover_release_gate.dart").read_text()
    tests = Path("test/storage/m180_encrypted_custom_goal_suggestions_test.dart").read_text()
    required_bridge = [
        "Future<List<String>> _customGoalRowsUnderLock()",
        "Future<List<String>> loadCustomGoalSuggestions()",
        "Future<bool> addCustomGoalSuggestion(String suggestion)",
        "await _requireActivatedUnderLock();",
        "await snapshot.read();",
        "snapshot.store.transaction(() async {",
        "return _customGoalRowsUnderLock();",
        "Encrypted custom goal projection is inconsistent.",
        "INSERT INTO fresh_finance_custom_goals(position,suggestion)",
    ]
    if any(fragment not in bridge for fragment in required_bridge):
        raise SystemExit("M180: typed encrypted custom goal bridge is missing")
    if "fresh_finance_custom_goals" not in bootstrap:
        raise SystemExit("M180: fresh vault does not create custom goals table")
    if "return bridge.addCustomGoalSuggestion(name);" not in session or (
            "return bridge.loadCustomGoalSuggestions();" not in session):
        raise SystemExit("M180: SQLCipher session not wired")
    if "return encryptedSession!.loadCustomGoalSuggestions();" not in authority or (
            "return encryptedSession!.addCustomGoalSuggestion(name);" not in authority):
        raise SystemExit("M180: verified finance authority bypass is possible")
    if ("all_live_writers_not_yet_routed" not in source_guard or
        "bool get automaticallyActivateSqlCipher => false;" not in release):
        raise SystemExit("M180: production cutover guard altered")
    for scenario in [
        "deduplicates case-insensitive racing writers",
        "corrupted typed SQL sequence fails closed",
        "pending source marker blocks",
        "default-off session cannot",
    ]:
        if scenario not in tests:
            raise SystemExit("M180: essential negative test missing")
    result = {
        "milestone": "M180", "reviewed_sha": head, "base_sha": base,
        "changed_paths": sorted(changed),
        "encrypted_custom_goal_route_candidate": True,
        "production_source_activated": False,
        "all_24_routes_attested_on_real_devices": False,
        "physical_two_device_restore_attested": False,
        "release_authorized": False,
        "status": "ENCRYPTED_CUSTOM_GOAL_CANDIDATE_RELEASE_NO_GO",
    }
    report = Path("build/m147-final-review-report.json")
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))

if __name__ == "__main__":
    inspect()
