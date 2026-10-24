#!/usr/bin/env python3
"""Exact-head five-file M185 finance module SQLCipher recycle review, NO-GO."""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess

FILES = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/m185-encrypted-module-recycle.md",
    "lib/storage/waffra_encrypted_module_recycle.dart",
    "scripts/qa/m185_module_recycle_scope_review.py",
    "test/storage/m185_encrypted_module_recycle_test.dart",
}


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], check=True, text=True, capture_output=True,
    ).stdout.strip()


def main() -> None:
    sha = git("rev-parse", "HEAD")
    if not os.environ.get("REVIEW_HEAD_SHA", "").strip() == sha:
        raise SystemExit("M185: exact PR HEAD evidence is mandatory")
    base = git("rev-parse", "refs/remotes/origin/main")
    if git("merge-base", base, sha) != base:
        raise SystemExit("M185: main advanced, rebase required")
    changed = set(filter(None, git(
        "diff", "--name-only", base, sha,
    ).splitlines()))
    if changed != FILES:
        raise SystemExit("M185: unauthorized file changes " +
                         repr(sorted(changed ^ FILES)))
    code = Path("lib/storage/waffra_encrypted_module_recycle.dart").read_text()
    tests = Path("test/storage/m185_encrypted_module_recycle_test.dart").read_text()
    source = Path("lib/storage/waffra_production_finance_source_guard.dart").read_text()
    release = Path("lib/storage/waffra_production_cutover_release_gate.dart").read_text()
    for marker in [
        "class WaffraEncryptedModuleRecycle",
        "WaffraFinanceModule.categories",
        "WaffraFinanceModule.goals",
        "WaffraFinanceModule.recurring",
        "Future<WaffraEncryptedModuleRecycleResult> softDelete(",
        "Future<WaffraEncryptedModuleRecycleResult> restore(",
        "WaffraEncryptedModuleProjectionGuard.reconcile(",
        "WaffraExperimentalWriterGate(",
        "await verifySourceUnderLock();",
        "snapshot.store.transaction(() async {",
        "source_sha256 TEXT NOT NULL",
        "Encrypted module trash checksum or clock differs.",
        "Encrypted module changed after user confirmation.",
        "await snapshot.commit(",
        "Finance module",
        "Delete child categories before their parent.",
        "Resolve pending recurring postings before deletion.",
        "Restore the deleted parent category first.",
        "entity['budget'] = 0.0",
        "entity['saved'] = 0.0",
        "Encrypted module recovery expired or clock rolled back.",
        "experimentalEnabled = false",
    ]:
        if marker not in code:
            raise SystemExit("M185: missing source safety marker " + marker)
    for scenario in [
        "goal recycle preserves transactions",
        "category parent deletion blocks live children",
        "recurring trash protects pending postponements",
        "stale Home witness blocks delete and restore",
        "expired or rolled-back restore",
        "typed SQL tampering prevents",
        "trash checksum tamper",
        "missing SQL tombstone rejects",
        "consent and source-mismatch failures",
        "encrypted recycle is default-disabled",
    ]:
        if scenario not in tests:
            raise SystemExit("M185: missing negative test " + scenario)
    if "all_live_writers_not_yet_routed" not in source or (
        "bool get automaticallyActivateSqlCipher => false;" not in release
    ):
        raise SystemExit("M185: production activation guard changed")
    documentation = Path("docs/qa/m185-encrypted-module-recycle.md").read_text()
    for item in ["source-gated standalone", "24/24 actual live route witnesses", "NO-GO"]:
        if item not in documentation:
            raise SystemExit("M185: missing release caveat " + item)
    result = {
        "milestone": "M185",
        "exact_sha": sha,
        "base_main_sha": base,
        "changed_files": sorted(changed),
        "encrypted_module_trash_candidate_staged": True,
        "source_verified_live_home_widget": False,
        "real_two_phone_restore_evidence": False,
        "24_live_routes_certified": False,
        "production_sqlcipher_cutover_enabled": False,
        "status": "M185_STANDALONE_MODULE_RECYCLE_CANDIDATE_NO_GO",
    }
    output = Path("build/m147-final-review-report.json")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
