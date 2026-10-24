#!/usr/bin/env python3
"""M181 exact-SHA review for actual routes; NEVER certifies production cutover."""
from __future__ import annotations

import json
import os
from pathlib import Path
import re
import subprocess

EXPECTED = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/m181-live-24-route-evidence-matrix.md",
    "lib/main.dart",
    "lib/storage/waffra_encrypted_finance_session.dart",
    "lib/storage/waffra_verified_encrypted_finance_bridge.dart",
    "lib/storage/waffra_verified_finance_authority.dart",
    "scripts/qa/m181_live_route_scope_review.py",
    "test/storage/m181_encrypted_catalog_atomic_install_test.dart",
}


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], text=True, capture_output=True, check=True,
    ).stdout.strip()


def require_all(text: str, fragments: list[str], source: str) -> None:
    missing = [fragment for fragment in fragments if fragment not in text]
    if missing:
        raise SystemExit(f"M181: {source} lacks guards: {missing!r}")


def main() -> None:
    head = git("rev-parse", "HEAD")
    requested = os.getenv("REVIEW_HEAD_SHA", "").strip()
    if not requested or head != requested:
        raise SystemExit("M181: exact reviewed PR SHA required")
    origin = git("rev-parse", "refs/remotes/origin/main")
    if git("merge-base", origin, head) != origin:
        raise SystemExit("M181: main advanced or branch diverged")
    paths = set(filter(
        None, git("diff", "--name-only", origin, head).splitlines(),
    ))
    if paths != EXPECTED:
        raise SystemExit("M181: unexpected file changes "
                         + repr(sorted(paths ^ EXPECTED)))

    root = Path("lib/storage")
    enumerated = (root / "waffra_production_finance_routing_gate.dart").read_text()
    match = re.search(r"enum WaffraFinanceRoute\s*\{([^}]*)\}", enumerated)
    if not match:
        raise SystemExit("M181: finance route inventory missing")
    routes = [
        line.strip().rstrip(",")
        for line in match.group(1).splitlines()
        if line.strip() and not line.strip().startswith("//")
    ]
    if len(routes) != 24 or len(set(routes)) != 24:
        raise SystemExit("M181: expected 24 distinct source routes")

    bridge = (root / "waffra_verified_encrypted_finance_bridge.dart").read_text()
    session = (root / "waffra_encrypted_finance_session.dart").read_text()
    authority = (root / "waffra_verified_finance_authority.dart").read_text()
    source = (root / "waffra_production_finance_source_guard.dart").read_text()
    release = (root / "waffra_production_cutover_release_gate.dart").read_text()
    home = Path("lib/main.dart").read_text()
    tests = Path(
        "test/storage/m181_encrypted_catalog_atomic_install_test.dart",
    ).read_text()
    require_all(bridge, [
        "Future<WaffraFinanceSnapshotState> installCategoryCatalog(",
        "WaffraEncryptedModuleProjectionGuard.reconcile(",
        "snapshot.store.transaction(() async {",
        "fresh_finance_settings(setting_key,value_json)",
        "await _requireActivatedUnderLock();",
        "Future<WaffraFinanceSnapshotState> deleteAllUnattachedTransactions(",
        "Encrypted receipts require retention review.",
        "DELETE FROM fresh_finance_entries",
        "DELETE FROM fresh_finance_sms_hashes",
        "Finance changed; reload before deleting.",
    ], "SQLCipher bridge")
    require_all(session, [
        "bridge.installCategoryCatalog(",
        "bridge.deleteAllUnattachedTransactions(",
        "_requireEnabled();",
    ], "verified session")
    require_all(authority, [
        "route == WaffraFinanceRoute.manualTransactionSave",
        "await encryptedSession!.appendConfirmed(",
        "hashes: const <String?>[null]",
        "route == WaffraFinanceRoute.deleteAllTransactions",
        "if (!userConfirmed || witness == null",
        "route == WaffraFinanceRoute.challengeAndBudgetUpdate",
        "route == WaffraFinanceRoute.recurringPostingAndPostponement",
        "route == WaffraFinanceRoute.merchantRulesAndSmsHashes",
        "Encrypted screen mutation requires a verified atomic SQL projection writer.",
        "await encryptedSession!.installCategoryCatalog(",
    ], "finance source authority")
    require_all(home, [
        "route:WaffraFinanceRoute.deleteAllTransactions,",
        "baseline:baseline,captured:captured,userConfirmed:true,",
    ], "Home explicit delete consent")
    require_all(tests, [
        "v2+v3 install is typed, atomic",
        "stale category catalog is refused",
        "invalid category projection rolls back",
        "manual Home add uses atomic typed SQL",
        "manual Home duplicate ID fails",
        "stale budget change fails",
        "recurring payment cannot write ledger via scalar shortcut",
        "consented empty-receipt delete-all",
        "delete-all requires explicit consent",
        "delete-all blocks orphan receipt SQL",
    ], "negative Flutter integration tests")
    require_all(source, ["all_live_writers_not_yet_routed"],
                "unactivated legacy source guard")
    require_all(release, [
        "bool get automaticallyActivateSqlCipher => false;",
    ], "release NO-GO gate")
    evidence = {
        "milestone": "M181",
        "exact_reviewed_sha": head,
        "base_main_sha": origin,
        "changed_paths": sorted(paths),
        "route_inventory_count": len(routes),
        "source_selected_sql_candidate_implementations": [
            "categoryCatalogInstall v2/v3",
            "manualTransactionSave",
            "challengeAndBudgetUpdate",
            "recurringPostingAndPostponement: postponement only",
            "merchantRulesAndSmsHashes: learned merchant map",
            "deleteAllTransactions: unattached records only",
        ],
        "all_24_live_routes_independently_proven": False,
        "encrypted_source_activated": False,
        "two_real_android_phones_tested": False,
        "production_release_authorized": False,
        "status": "M181_CODE_STAGED_PRODUCTION_NO_GO",
    }
    output = Path("build/m147-final-review-report.json")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(evidence, indent=2) + "\n")
    print(json.dumps(evidence, indent=2))


if __name__ == "__main__":
    main()
