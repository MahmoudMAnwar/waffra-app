#!/usr/bin/env python3
"""SHA-pinned M179 source-aware scalar scope review, never GO-LIVE."""
from __future__ import annotations
import json
import os
from pathlib import Path
import subprocess

EXPECTED = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/m179-encrypted-recurring-scalar.md",
    "lib/storage/waffra_encrypted_finance_session.dart",
    "lib/storage/waffra_verified_finance_authority.dart",
    "scripts/qa/m179_recurring_scalar_scope_review.py",
    "test/storage/m179_encrypted_recurring_scalar_test.dart",
}

def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], check=True, text=True, capture_output=True,
    ).stdout.strip()

def run() -> None:
    head = git("rev-parse", "HEAD")
    review_head = os.environ.get("REVIEW_HEAD_SHA", "").strip()
    if not review_head or head != review_head:
        raise SystemExit("M179: PR HEAD does not match scope witness")
    baseline = git("rev-parse", "refs/remotes/origin/main")
    if git("merge-base", baseline, head) != baseline:
        raise SystemExit("M179: diverged from reviewed main")
    changed = set(filter(None, git(
        "diff", "--name-only", baseline, head,
    ).splitlines()))
    if changed != EXPECTED:
        raise SystemExit("M179: unexpected file changes " +
                         repr(sorted(changed ^ EXPECTED)))
    authority = Path("lib/storage/waffra_verified_finance_authority.dart").read_text()
    session = Path("lib/storage/waffra_encrypted_finance_session.dart").read_text()
    routing = Path("lib/storage/waffra_production_finance_source_guard.dart").read_text()
    release = Path("lib/storage/waffra_production_cutover_release_gate.dart").read_text()
    tests = Path("test/storage/m179_encrypted_recurring_scalar_test.dart").read_text()
    authority_bound = authority[
        authority.index("Future<WaffraFinanceAuthorityRead> setRecurringReminderPreference("):
        authority.index("Future<List<String>> loadCustomGoalSuggestions()")
    ]
    required = [
        "WaffraFinanceRoute.recurringCreateEditDeleteRestore",
        "if (backend == WaffraRuntimeFinanceBackend.guardedLegacy)",
        "await legacy.setRecurringReminderPreference(enabled)",
        "await encryptedSession!.loadForDashboardOrWidget()",
        "await encryptedSession!.saveRecurringReminderPreference(",
        "return load(route: WaffraFinanceRoute.recurringCreateEditDeleteRestore)",
    ]
    if any(s not in authority_bound for s in required):
        raise SystemExit("M179: recurring scalar has an unauthorized write path")
    if "_homeFinancePersistence.withLegacyWriter(" in Path("lib/main.dart").read_text():
        raise SystemExit("M179: Home legacy direct-write bypass reappeared")
    if "saveChangedFields(" not in session or (
            "'waffra_recurring_reminders_enabled_v1': enabled" not in session):
        raise SystemExit("M179: encrypted atomic scalar route not implemented")
    if "all_live_writers_not_yet_routed" not in routing or (
            "bool get automaticallyActivateSqlCipher => false;" not in release):
        raise SystemExit("M179: production NO-GO source guard removed")
    for evidence in [
        "stale scalar cannot overwrite",
        "unrelated concurrent SMS hash survives",
        "pending witness blocks",
        "disabled session refuses",
    ]:
        if evidence not in tests:
            raise SystemExit("M179: missing race/source negative test")
    result = {
        "milestone": "M179", "reviewed_sha": head, "base_main_sha": baseline,
        "changed_files": sorted(changed),
        "encrypted_recurring_scalar_writer_staged": True,
        "production_sqlcipher_enabled": False,
        "24_real_route_witnesses": False,
        "real_android_devices_tested": False,
        "status": "ENCRYPTED_RECURRING_SCALAR_STAGED_NO_GO",
    }
    path = Path("build/m147-final-review-report.json")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(result, ensure_ascii=True, indent=2) + "\n")
    print(json.dumps(result))

if __name__ == "__main__":
    run()
