#!/usr/bin/env python3
"""M230 cumulative SQLCipher preflight + refresh scope gate (QA only).

This gate checks the entire reviewed diff and each commit; never claims
production route activation, physical phone proof, or restore parity.
"""
from __future__ import annotations
import os
from pathlib import Path
import subprocess

BASE = "8a460fa3d537ee7e8343b01e49d794140e66652a"
EXPECTED = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/release/WAFFRA_APPROVED_CHANGES.txt",
    "docs/qa/m228-24-route-source-preflight.md",
    "docs/qa/m230-stage1-consolidation.md",
    "lib/main.dart",
    "lib/storage/waffra_verified_pull_refresh_source.dart",
    "lib/storage/waffra_finance_24_route_preflight.dart",
    "lib/storage/waffra_production_finance_authority_binding.dart",
    "scripts/qa/m228_verified_pull_refresh_scope_review.py",
    "scripts/qa/m228_route_readiness_scope_review.py",
    "scripts/qa/m230_combined_stage1_refresh_review.py",
    "test/m224_verified_pull_refresh_dialog_test.dart",
    "test/storage/m228_verified_pull_refresh_source_test.dart",
    "test/storage/m228_24_route_preflight_test.dart",
}

def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True).strip()

def require(condition: bool, reason: str) -> None:
    if not condition:
        raise SystemExit("M230 BLOCKED: " + reason)

def has(path: str, *parts: str) -> None:
    contents = Path(path).read_text(encoding="utf-8")
    for token in parts:
        require(token in contents, f"{path}: missing {token}")

def main() -> None:
    head = git("rev-parse", "HEAD")
    base = git("rev-parse", "refs/remotes/origin/main")
    require(head == os.environ.get("REVIEW_HEAD_SHA"), "incorrect tested head")
    require(base == BASE, "main advanced: review against new exact main")
    require(git("merge-base", head, base) == base, "candidate diverged from main")
    commits = git("rev-list", "--reverse", BASE + ".." + head).splitlines()
    require(2 <= len(commits) <= 24, "unexpected unbounded patch history")
    for sha in commits:
        ancestry = git("rev-list", "--parents", "-n", "1", sha).split()
        require(len(ancestry) == 2, "unreviewed merge commit")
        paths = set(filter(None, git("diff-tree", "--no-commit-id",
                                    "--name-only", "-r", sha).splitlines()))
        require(bool(paths) and paths <= EXPECTED, "unapproved commit paths")
    changed = set(filter(None, git("diff", "--name-only", BASE, head).splitlines()))
    require(changed == EXPECTED, "unexpected cumulative diff: " +
            repr(sorted(changed ^ EXPECTED)))
    route = Path("lib/storage/waffra_production_finance_routing_gate.dart").read_text()
    import re
    enum = re.search(r"enum WaffraFinanceRoute\s*\{([^}]*)\}", route)
    require(enum is not None, "24-route enum absent")
    members = [line.strip().rstrip(",") for line in enum.group(1).splitlines()
               if line.strip() and not line.lstrip().startswith("//")]
    require(len(members) == len(set(members)) == 24, "24 unique routes missing")
    has("lib/storage/waffra_finance_24_route_preflight.dart",
        "WaffraFinanceRoute.values", "selector.requireRoute(route)",
        "productionCutoverAuthorized => false")
    has("lib/storage/waffra_production_finance_authority_binding.dart",
        "checkpoint.sourceDigest != evidence.storage.sourceDigest",
        "WaffraFinance24RoutePreflight().inspect(",
        "if (!routePreflight.allContractsAcceptEncrypted)")
    has("lib/storage/waffra_verified_pull_refresh_source.dart",
        "current.finance.requireIntegrity();",
        "current.source == WaffraRuntimeFinanceBackend.verifiedEncrypted",
        "ledgerRaw: ledger ?? '[]'")
    has("lib/main.dart", "await _financialWriteQueue.drain();",
        "WaffraVerifiedPullRefreshSource.fromAuthority(current)",
        "current.source==WaffraRuntimeFinanceBackend.guardedLegacy")
    has("lib/storage/waffra_production_cutover_release_gate.dart",
        "bool get automaticallyActivateSqlCipher => false;")
    has("test/storage/m228_24_route_preflight_test.dart",
        "for (final missing in WaffraFinanceRoute.values)",
        "missing ${missing.name} blocks the entire encrypted source")
    has("test/storage/m228_verified_pull_refresh_source_test.dart",
        "incomplete encrypted catalog still fails closed",
        "missing encrypted ledger still fails closed")
    has(".github/workflows/m147-final-main-review-gate.yml",
        "python3 scripts/qa/m230_combined_stage1_refresh_review.py")
    # Keep the M147 artifact contract: a complete audit must leave a
    # machine-readable, explicitly non-authorizing QA report for review.
    import json
    report = {
        "milestone": "M230",
        "reviewed_head_sha": head,
        "base_main_sha": base,
        "reviewed_commit_count": len(commits),
        "changed_paths": sorted(changed),
        "route_contract_count": len(members),
        "source_scope_verified": True,
        "pull_refresh_code_scope_verified": True,
        "sqlcipher_production_activated": False,
        "all_24_live_routes_verified": False,
        "two_physical_phones_verified": False,
        "original_sms_notes_restore_parity_verified": False,
        "production_release_authorized": False,
        "status": "M230_CODE_SCOPE_QA_ONLY_PRODUCTION_NO_GO",
    }
    output = Path("build/m147-final-review-report.json")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n",
                      encoding="utf-8")
    print("M230 PASS: exact-head review of both isolated fixes, no SQLCipher activation; real phones still NO-GO.")

if __name__ == "__main__":
    main()
