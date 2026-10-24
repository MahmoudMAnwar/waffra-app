#!/usr/bin/env python3
"""M177 exact PR-head diff audit. Not production authorization."""
import json
import os
from pathlib import Path
import subprocess

ALLOWED = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/m177-auxiliary-writer-source-gates.md",
    "lib/main.dart",
    "lib/storage/waffra_verified_finance_authority.dart",
    "scripts/qa/m177_auxiliary_writer_scope_review.py",
    "test/storage/m177_auxiliary_writer_source_gate_test.dart",
}


def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()


def inspect():
    sha = git("rev-parse", "HEAD")
    if sha != os.environ.get("REVIEW_HEAD_SHA"):
        raise SystemExit("M177 blocked: head SHA changed during review")
    main = git("rev-parse", "refs/remotes/origin/main")
    if git("merge-base", main, sha) != main:
        raise SystemExit("M177 blocked: main is not an ancestor")
    changed = set(filter(None, git("diff", "--name-only", main, sha).splitlines()))
    if changed != ALLOWED:
        raise SystemExit("M177 blocked: unexpected scope: "
                         + repr(sorted(changed ^ ALLOWED)))
    home = Path("lib/main.dart").read_text()
    authority = Path("lib/storage/waffra_verified_finance_authority.dart").read_text()
    if "_homeFinancePersistence.withLegacyWriter(" in home or (
        "_homeFinancePersistence.loadCustomGoalSuggestions(" in home
        or "_homeFinancePersistence.addCustomGoalSuggestion(" in home
    ):
        raise SystemExit("M177 blocked: Home still bypasses authority")
    for name in ("mergeSmsFingerprints", "saveRecurringReminderSetting",
                 "loadCustomGoalSuggestions", "addCustomGoalSuggestion",
                 "installCategoryCatalog"):
        if name + "(" not in home or name + "(" not in authority:
            raise SystemExit("M177 blocked: missing routed writer " + name)
    if ("all_live_writers_not_yet_routed" not in
        Path("lib/storage/waffra_production_finance_source_guard.dart").read_text()
        or "bool get automaticallyActivateSqlCipher => false;" not in
        Path("lib/storage/waffra_production_cutover_release_gate.dart").read_text()):
        raise SystemExit("M177 blocked: production NO-GO policy changed")
    return {
        "milestone": "M177", "head": sha, "base": main,
        "changed_paths": sorted(changed),
        "home_auxiliary_direct_legacy_calls": 0,
        "source_activation": False, "user_data_migrated": False,
        "sql_catalog_atomic_writer_verified": False,
        "all_24_routes_verified": False, "production_release_ready": False,
        "status": "M177_AUXILIARY_WRITERS_ROUTED_PRODUCTION_NO_GO",
    }


if __name__ == "__main__":
    report = inspect()
    path = Path("build/m147-final-review-report.json")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
