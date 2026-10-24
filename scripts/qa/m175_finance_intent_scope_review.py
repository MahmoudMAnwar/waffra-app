#!/usr/bin/env python3
"""M175 fixed-scope app mutation review, not production SQLCipher activation."""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess

ALLOWED = {
    "lib/main.dart",
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/m175-finance-route-intent.md",
    "scripts/qa/m175_finance_intent_scope_review.py",
    "test/m110_live_finance_authority_writer_test.dart",
    "test/storage/m175_live_finance_mutation_intent_test.dart",
}


def git(*args: str) -> str:
    return subprocess.run(["git", *args], check=True,
                          capture_output=True, text=True).stdout.strip()


def inspect() -> dict:
    head = git("rev-parse", "HEAD")
    approved = os.environ.get("REVIEW_HEAD_SHA", "").strip()
    if not approved or head != approved:
        raise SystemExit("M175 BLOCKED: not testing exact reviewed head")
    main = git("rev-parse", "refs/remotes/origin/main")
    if git("merge-base", main, head) != main:
        raise SystemExit("M175 BLOCKED: PR not descended from current main")
    changed = set(filter(None, git("diff", "--name-only", main, head).splitlines()))
    if changed != ALLOWED:
        raise SystemExit("M175 BLOCKED: finance diff scope changed. missing="
                         + repr(sorted(ALLOWED - changed))
                         + " extra=" + repr(sorted(changed - ALLOWED)))
    home = Path("lib/main.dart").read_text(encoding="utf-8")
    required = (
        "WaffraFinanceRoute route = WaffraFinanceRoute.transactionEdit,",
        "route:route,\n    baseline:baseline,",
        "WaffraFinanceRoute.manualTransactionSave",
        "WaffraFinanceRoute.transactionDeleteAndUndo",
        "WaffraFinanceRoute.recurringPostingAndPostponement",
    )
    if any(mark not in home for mark in required):
        raise SystemExit("M175 BLOCKED: intended route binding is missing")
    source_guard = Path(
        "lib/storage/waffra_production_finance_source_guard.dart").read_text()
    release_guard = Path(
        "lib/storage/waffra_production_cutover_release_gate.dart").read_text()
    if ("all_live_writers_not_yet_routed" not in source_guard
            or "bool get automaticallyActivateSqlCipher => false;" not in release_guard):
        raise SystemExit("M175 BLOCKED: must retain production fail-closed gates")
    return {
        "milestone": "M175",
        "head_sha": head,
        "main_baseline_sha": main,
        "changed_paths": sorted(changed),
        "intent_tagged": [
            "manualTransactionSave", "transactionEdit",
            "transactionDeleteAndUndo", "recurringPostingAndPostponement",
        ],
        "sqlcipher_production_activated": False,
        "migration_performed": False,
        "signed_device_attested": False,
        "24_route_prod_readiness": False,
        "status": "WIRING_PROVENANCE_ONLY_PRODUCTION_NO_GO",
    }


if __name__ == "__main__":
    result = inspect()
    artifact = Path("build/m147-final-review-report.json")
    artifact.parent.mkdir(parents=True, exist_ok=True)
    artifact.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
