#!/usr/bin/env python3
"""Exact-head M186 Home/Authority encrypted module trash review. NO-GO."""
from __future__ import annotations
import json
import os
from pathlib import Path
import subprocess

EXPECTED = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/m186-verified-module-home-routing.md",
    "lib/main.dart",
    "lib/waffra_recurring_trash.part.dart",
    "lib/storage/waffra_encrypted_finance_session.dart",
    "lib/storage/waffra_verified_encrypted_finance_bridge.dart",
    "lib/storage/waffra_verified_finance_authority.dart",
    "lib/storage/waffra_verified_module_ui_guard.dart",
    "scripts/qa/m186_module_home_route_review.py",
    "test/storage/m186_module_authority_ui_gate_test.dart",
}

def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], check=True, text=True, capture_output=True,
    ).stdout.strip()

def require(content: str, markers: list[str], name: str) -> None:
    for marker in markers:
        if marker not in content:
            raise SystemExit(f"M186: missing {name} verified guard {marker!r}")

def main() -> None:
    current = git("rev-parse", "HEAD")
    if not os.environ.get("REVIEW_HEAD_SHA", "").strip() == current:
        raise SystemExit("M186: only same-head source review accepted")
    base = git("rev-parse", "refs/remotes/origin/main")
    if git("merge-base", base, current) != base:
        raise SystemExit("M186: latest main must be an ancestor")
    changed = set(filter(None, git(
        "diff", "--name-only", base, current,
    ).splitlines()))
    if changed != EXPECTED:
        raise SystemExit("M186: exact 10-file review scope mismatch " +
                         repr(sorted(changed ^ EXPECTED)))

    root = Path("lib/storage")
    authority = (root / "waffra_verified_finance_authority.dart").read_text()
    bridge = (root / "waffra_verified_encrypted_finance_bridge.dart").read_text()
    session = (root / "waffra_encrypted_finance_session.dart").read_text()
    ui = Path("lib/main.dart").read_text()
    recurring = Path("lib/waffra_recurring_trash.part.dart").read_text()
    guard = (root / "waffra_verified_module_ui_guard.dart").read_text()
    tests = Path("test/storage/m186_module_authority_ui_gate_test.dart").read_text()
    source = (root / "waffra_production_finance_source_guard.dart").read_text()
    release = (root / "waffra_production_cutover_release_gate.dart").read_text()
    docs = Path("docs/qa/m186-verified-module-home-routing.md").read_text()

    require(authority, [
        "Future<WaffraFinanceAuthorityRead> deleteVerifiedModuleToRecycle(",
        "Future<WaffraFinanceAuthorityRead> restoreVerifiedDeletedModule(",
        "Future<Map<String, int>> listVerifiedDeletedModules(",
        "baseline.source != WaffraRuntimeFinanceBackend.verifiedEncrypted",
        "baseline.encryptedWitness == null",
        "await encryptedSession!.recycleVerifiedModule(",
        "await encryptedSession!.restoreVerifiedModule(",
        "return await load(route: route);",
    ], "finance source selector")
    require(session, [
        "Future<WaffraEncryptedModuleRecycleResult> recycleVerifiedModule(",
        "Future<WaffraEncryptedModuleRecycleResult> restoreVerifiedModule(",
        "bridge.recycleVerifiedModule(",
        "bridge.restoreVerifiedModule(",
        "_requireEnabled();",
    ], "encrypted session")
    require(bridge, [
        "WaffraEncryptedModuleRecycle get _verifiedModuleRecycle",
        "verifySourceUnderLock: _requireActivatedUnderLock",
        "return _verifiedModuleRecycle.softDelete(",
        "return _verifiedModuleRecycle.restore(",
        "return _verifiedModuleRecycle.pending(module);",
    ], "SQLCipher bridge")
    require(ui, [
        "Future<void> _deleteVerifiedModule({",
        "Future<void> _restoreVerifiedModule({",
        "Future<void> _showVerifiedModuleTrash(WaffraFinanceModule module)",
        "_financialWriteQueue.drain();",
        "WaffraVerifiedModuleUiGuard.requireUnchanged(",
        "await _financeAuthority.deleteVerifiedModuleToRecycle(",
        "await _financeAuthority.restoreVerifiedDeletedModule(",
        "await _financeAuthority.listVerifiedDeletedModules(module)",
        "await _loadFinanceSafely();",
        "WaffraRuntimeFinanceBackend.verifiedEncrypted",
        "WaffraFinanceModule.goals,displayed:g.toJson()",
        "WaffraFinanceModule.categories,displayed:c.toJson()",
        "WaffraFinanceModule.recurring,displayed:r.toJson()",
        "final verifiedEncryptedStartup=",
        "Verified encrypted category source is incomplete.",
        "if(!verifiedEncryptedStartup&&",
        "if(!verifiedEncryptedStartup)for(final e in entries)",
        "if(!verifiedEncryptedStartup&&trashBefore!=deletedCategories.length)",
        "Home reloading an encrypted ledger must never silently post a due payment.",
    ], "conditional Home screen")
    require(recurring, [
        "WaffraRuntimeFinanceBackend.verifiedEncrypted",
        "_showVerifiedModuleTrash(WaffraFinanceModule.recurring);",
    ], "recurring trash UI")
    require(guard, [
        "static void requireUnchanged(",
        "static List<Map<String, dynamic>> verifiedTrash(",
        "Encrypted module trash and UI metadata differ.",
        "Selected financial entity changed before confirmation.",
    ], "pure UI witness")
    require(tests, [
        "goal delete/read/undo resets only saved balance",
        "category budget zero after verified source restore",
        "recurring recovery remains paused",
        "legacy source cannot reach encrypted module delete/undo",
        "stale module read and malformed UI cannot erase typed SQL",
        "trashed IDs are authoritative SQL witnesses",
    ], "disposable SQLCipher negative tests")
    require(source, ["all_live_writers_not_yet_routed"],
            "unactivated production source")
    require(release, [
        "bool get automaticallyActivateSqlCipher => false;",
    ], "production NO-GO")
    require(docs, [
        "parent-first", "NO-GO", "not on-device evidence",
    ], "uncertified release caveats")

    proof = {
        "milestone": "M186",
        "reviewed_head_sha": current,
        "base_main_sha": base,
        "changed_paths": sorted(changed),
        "conditional_home_authority_module_trash_staged": True,
        "production_sqlcipher_source_activated": False,
        "twenty_four_live_routes_real_device_certified": False,
        "two_phone_backup_restore_tested": False,
        "status": "M186_VERIFIED_MODULE_UI_STAGED_NO_GO",
    }
    file = Path("build/m147-final-review-report.json")
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_text(json.dumps(proof, indent=2) + "\n")
    print(json.dumps(proof, indent=2))

if __name__ == "__main__":
    main()
