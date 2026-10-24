#!/usr/bin/env python3
"""M176 exact-SHA scope + finance intent evidence; never a release approval."""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess

EXPECTED = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/m176-module-intent-routing.md",
    "lib/main.dart",
    "lib/waffra_recurring_trash.part.dart",
    "scripts/qa/m176_module_intent_scope_review.py",
    "test/storage/m176_module_finance_route_intent_test.dart",
}

EXPECTED_ROUTE_COUNTS = {
    "categoryCreateEditDeleteRestore": 10,
    "goalCreateEditDeleteRestore": 6,
    "recurringCreateEditDeleteRestore": 3,
    "challengeAndBudgetUpdate": 4,
}


def git(*args: str) -> str:
    return subprocess.run(["git", *args], capture_output=True,
                          check=True, text=True).stdout.strip()


def inspect() -> dict:
    head = git("rev-parse", "HEAD")
    expected_sha = os.environ.get("REVIEW_HEAD_SHA", "").strip()
    if not expected_sha or expected_sha != head:
        raise SystemExit("M176 blocked: reviewed head SHA mismatch")
    main = git("rev-parse", "refs/remotes/origin/main")
    if git("merge-base", main, head) != main:
        raise SystemExit("M176 blocked: not descended from main")
    changed = set(filter(None, git("diff", "--name-only", main, head).splitlines()))
    if changed != EXPECTED:
        raise SystemExit("M176 blocked: unexpected file scope; missing "
                         + repr(sorted(EXPECTED - changed)) + ", extras "
                         + repr(sorted(changed - EXPECTED)))
    home = Path("lib/main.dart").read_text(encoding="utf-8")
    recurring = Path("lib/waffra_recurring_trash.part.dart").read_text(
        encoding="utf-8")
    for route, number in EXPECTED_ROUTE_COUNTS.items():
        tag = "persist(route:WaffraFinanceRoute." + route + ")"
        if home.count(tag) != number:
            raise SystemExit("M176 blocked: changed source contract for " + route)
    if recurring.count(
        "persist(route:WaffraFinanceRoute.recurringCreateEditDeleteRestore)"
    ) != 3:
        raise SystemExit("M176 blocked: recurring recycle calls not all tagged")
    if ("all_live_writers_not_yet_routed" not in
        Path("lib/storage/waffra_production_finance_source_guard.dart").read_text()
        or "bool get automaticallyActivateSqlCipher => false;" not in
        Path("lib/storage/waffra_production_cutover_release_gate.dart").read_text()):
        raise SystemExit("M176 blocked: fail-closed production source changed")
    return {
        "milestone": "M176",
        "reviewed_sha": head,
        "main_baseline": main,
        "changed_paths": sorted(changed),
        "intent_counts_home": EXPECTED_ROUTE_COUNTS,
        "intent_counts_recurring_trash": 3,
        "still_direct_legacy_calls": [
            "category_catalog_install_v2_v3",
            "custom_goal_suggestions",
            "recurring_reminder_toggle",
            "sms_hash_fallback",
        ],
        "runtime_sqlcipher_activated": False,
        "user_data_migrated": False,
        "all_24_routes_proven": False,
        "release_ready": False,
        "status": "M176_SOURCE_TAGGING_ONLY_PRODUCTION_NO_GO",
    }


if __name__ == "__main__":
    evidence = inspect()
    output = Path("build/m147-final-review-report.json")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(evidence, indent=2))
