#!/usr/bin/env python3
"""M182 exact PR SHA and eight-file scope; never activates encrypted finance."""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess

EXPECTED = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/m182-atomic-recurring-payment.md",
    "lib/main.dart",
    "lib/storage/waffra_encrypted_finance_session.dart",
    "lib/storage/waffra_verified_encrypted_finance_bridge.dart",
    "lib/storage/waffra_verified_finance_authority.dart",
    "scripts/qa/m182_recurring_atomic_scope_review.py",
    "test/storage/m182_encrypted_recurring_paid_atomic_test.dart",
    "test/storage/m175_live_finance_mutation_intent_test.dart",
}


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], text=True, check=True, capture_output=True,
    ).stdout.strip()


def main() -> None:
    head = git("rev-parse", "HEAD")
    expected = os.environ.get("REVIEW_HEAD_SHA", "").strip()
    if not expected or expected != head:
        raise SystemExit("M182: exact same-HEAD review is mandatory")
    base = git("rev-parse", "refs/remotes/origin/main")
    if git("merge-base", base, head) != base:
        raise SystemExit("M182: main diverged, scope review blocked")
    paths = set(filter(None, git(
        "diff", "--name-only", base, head,
    ).splitlines()))
    if paths != EXPECTED:
        raise SystemExit(
            f"M182: exactly nine reviewed files required: {sorted(paths ^ EXPECTED)}"
        )
    bridge = Path(
        "lib/storage/waffra_verified_encrypted_finance_bridge.dart",
    ).read_text()
    session = Path("lib/storage/waffra_encrypted_finance_session.dart").read_text()
    authority = Path(
        "lib/storage/waffra_verified_finance_authority.dart",
    ).read_text()
    ui = Path("lib/main.dart").read_text()
    tests = Path(
        "test/storage/m182_encrypted_recurring_paid_atomic_test.dart",
    ).read_text()
    source = Path(
        "lib/storage/waffra_production_finance_source_guard.dart",
    ).read_text()
    release = Path(
        "lib/storage/waffra_production_cutover_release_gate.dart",
    ).read_text()
    necessary_bridge = [
        "Future<WaffraFinanceSnapshotState> commitRecurringPayment(",
        "await _requireActivatedUnderLock();",
        "snapshot.store.transaction(() async {",
        "Recurring SQL projection count differs.",
        "Recurring typed SQL witness differs.",
        "Recurring payment SQL ledger is out of sync.",
        "Recurring posted payment differs from its schedule.",
        "Recurring payment may only clear its own postponement.",
        "INSERT INTO fresh_finance_entries",
        "return snapshot.commit(",
        "WaffraRecurringPolicy.entryId(",
        "userConfirmed",
    ]
    for requirement in necessary_bridge:
        if requirement not in bridge:
            raise SystemExit("M182: missing secure SQL operation " + requirement)
    for fragment in [
        "bridge.commitRecurringPayment(",
        "_requireEnabled();",
    ]:
        if fragment not in session:
            raise SystemExit("M182: encrypted session bypass " + fragment)
    for fragment in [
        "route == WaffraFinanceRoute.recurringPostingAndPostponement",
        "if (!userConfirmed ||",
        "await encryptedSession!.commitRecurringPayment(",
        "Recurring posting may append only one immutable entry.",
        "This recurring payment has already been posted.",
        "return await load(route: route);",
    ]:
        if fragment not in authority:
            raise SystemExit("M182: recurring source authority bypass " + fragment)
    for fragment in [
        "userConfirmed:userConfirmed,",
        "userConfirmed:true);",
        "WaffraFinanceRoute.recurringPostingAndPostponement",
    ]:
        if fragment not in ui:
            raise SystemExit("M182: missing explicit Paid user intent " + fragment)
    for scenario in [
        "clears postponement",
        "unrelated Widget hash",
        "unconfirmed Paid",
        "duplicate monthly recurring",
        "forged recurring amount",
        "stale postponement",
        "other finance edits",
        "receipt-bearing entry",
        "disabled encrypted finance session",
    ]:
        if scenario not in tests:
            raise SystemExit("M182: missing negative test " + scenario)
    if ("all_live_writers_not_yet_routed" not in source or
            "bool get automaticallyActivateSqlCipher => false;" not in release):
        raise SystemExit("M182: release production NO-GO source guard removed")
    data = {
        "milestone": "M182",
        "reviewed_sha": head,
        "base_main_sha": base,
        "paths": sorted(paths),
        "recurring_paid_sql_atomic_candidate_staged": True,
        "physical_android_witnesses": False,
        "all_24_live_routes_certified": False,
        "sqlcipher_activated": False,
        "final_release_authorized": False,
        "status": "M182_RECURRING_ATOMIC_CANDIDATE_NO_GO",
    }
    result = Path("build/m147-final-review-report.json")
    result.parent.mkdir(parents=True, exist_ok=True)
    result.write_text(json.dumps(data, indent=2) + "\n")
    print(json.dumps(data, indent=2))


if __name__ == "__main__":
    main()
