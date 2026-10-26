#!/usr/bin/env python3
"""M228 exact-main, fail-closed source/diff review; NEVER certifies SQLCipher cutover."""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess

EXPECTED = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/release/WAFFRA_APPROVED_CHANGES.txt",
    "lib/main.dart",
    "lib/storage/waffra_verified_pull_refresh_source.dart",
    "scripts/qa/m228_verified_pull_refresh_scope_review.py",
    "test/m224_verified_pull_refresh_dialog_test.dart",
    "test/storage/m228_verified_pull_refresh_source_test.dart",
}

def git(*args: str) -> str:
    return subprocess.run(["git", *args], check=True,
                          capture_output=True, text=True).stdout.strip()

def require(value: bool, message: str) -> None:
    if not value:
        raise SystemExit("M228 REVIEW BLOCKED: " + message)

def contains(path: str, fragments: tuple[str, ...]) -> None:
    source = Path(path).read_text(encoding="utf8")
    for fragment in fragments:
        require(fragment in source, path + " misses " + fragment)

def main() -> None:
    head = git("rev-parse", "HEAD")
    base = git("rev-parse", "refs/remotes/origin/main")
    require(head == os.environ.get("REVIEW_HEAD_SHA"),
            "candidate must match the exact PR head")
    require(git("merge-base", head, base) == base,
            "main moved or candidate not based on latest main")
    before, after = map(int, git("rev-list", "--left-right",
                                "--count", base + "..." + head).split())
    # Allow documented iterative QA fix commits, but inspect EVERY commit in
    # the PR and the exact cumulative file diff. No merge commits or unexpected
    # file edits can enter through the larger revision allowance.
    require(before == 0 and 1 <= after <= 12, "unexpected history")
    commits = git("rev-list", "--reverse", base + ".." + head).splitlines()
    require(len(commits) == after, "commit history changed during review")
    for commit in commits:
        parents = git("rev-list", "--parents", "-n", "1", commit).split()
        require(len(parents) == 2, "merge commit in reviewed patch history")
        changed_in_commit = set(filter(None, git(
            "diff-tree", "--no-commit-id", "--name-only", "-r", commit
        ).splitlines()))
        require(bool(changed_in_commit) and changed_in_commit <= EXPECTED,
                "unreviewed change in commit " + commit[:12])
    changed = set(filter(None, git("diff", "--name-only", base, head).splitlines()))
    require(changed == EXPECTED,
            "reviewed path mismatch: " + repr(sorted(changed ^ EXPECTED)))
    contains("lib/main.dart", (
        "await _financialWriteQueue.drain();",
        "route:WaffraFinanceRoute.dashboardRead",
        "view.requireIntegrity();",
        "WaffraVerifiedPullRefreshSource.fromAuthority(current)",
        "final nextCategories=catalog==null",
        "current.source==WaffraRuntimeFinanceBackend.guardedLegacy",
        "onRefresh:_refreshFromVerifiedFinance",
        "Verified pull refresh failed closed",
        "تعذر التحقق من البيانات أثناء التحديث",
    ))
    contains("lib/storage/waffra_verified_pull_refresh_source.dart", (
        "current.finance.requireIntegrity();",
        "current.source == WaffraRuntimeFinanceBackend.verifiedEncrypted",
        "(ledger == null || categories == null)",
        "throw StateError(",
        "ledgerRaw: ledger ?? '[]'",
    ))
    contains("test/storage/m228_verified_pull_refresh_source_test.dart", (
        "empty legacy first install",
        "saved ledger with missing optional legacy catalog",
        "existing empty category list",
        "incomplete encrypted catalog still fails closed",
        "missing encrypted ledger still fails closed",
        "invalid saved legacy ledger never falls back",
        "malformed category JSON remains an integrity failure",
    ))
    contains("test/m224_verified_pull_refresh_dialog_test.dart", (
        "WaffraVerifiedPullRefreshSource.fromAuthority(current)",
        "final nextCategories=catalog==null",
        "if(tab>0&&tab<4)",
    ))
    contains("lib/storage/waffra_production_cutover_release_gate.dart", (
        "bool get automaticallyActivateSqlCipher => false;",
    ))
    contains(".github/workflows/m147-final-main-review-gate.yml", (
        "python3 scripts/qa/m228_verified_pull_refresh_scope_review.py",
        "if: github.head_ref == 'fix/m228-verified-pull-refresh-first-install-20261026'",
    ))
    contains("docs/release/WAFFRA_APPROVED_CHANGES.txt", (
        "[M228]", "Android #705", "FAIL CLOSED",
    ))
    note = git("log", "-1", "--format=%H", "--",
               "docs/release/WAFFRA_APPROVED_CHANGES.txt")
    app = git("log", "-1", "--format=%H", "--", "lib/main.dart", "lib/storage")
    require(subprocess.run(["git", "merge-base", "--is-ancestor",
                            app, note]).returncode == 0,
            "approved notes must be newer than finance app code")
    report = {
        "milestone": "M228",
        "base_main_sha": base,
        "reviewed_head_sha": head,
        "changed_paths": sorted(changed),
        "source_scope_verified": True,
        "sqlcipher_production_activated": False,
        "all_24_live_routes_verified": False,
        "physical_device_verified": False,
        "production_release_authorized": False,
        "status": "M228_CODE_SCOPE_ONLY_QA_NOT_PRODUCTION",
    }
    output = Path("build/m147-final-review-report.json")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n",
                      encoding="utf8")
    print("M228 REVIEW PASS: exact main ancestry and diff, original privacy, "
          "strict SQLCipher rejection, release notes freshness. "
          "Physical-device/production SQLCipher authorization: NO.")

if __name__ == "__main__":
    main()
