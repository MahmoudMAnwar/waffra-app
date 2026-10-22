#!/usr/bin/env python3
"""Fail-closed *static* APK release review. This cannot certify physical devices.

Proves every routed finance surface has explicit production wiring before an APK
can be called FINAL. This is intentionally stricter than a build-only workflow:
a signed APK may be a TEST CANDIDATE despite a successful Gradle build.
"""
from __future__ import annotations
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "lib/main.dart"
WIDGET = ROOT / "lib/waffra_widget_capture.part.dart"
CLOUD = ROOT / "lib/storage/waffra_cloud_encrypted_pull_preview.dart"
ROUTER = ROOT / "lib/storage/waffra_production_finance_source_guard.dart"
RESTORE = ROOT / "lib/storage/waffra_portable_encrypted_vault_restorer.dart"
ACTIONS = ROOT / ".github/workflows/android.yml"

def read(path: Path) -> str:
    if not path.is_file():
        return ""
    return path.read_text(encoding="utf-8")

def inspect() -> dict:
    app = read(APP)
    widget = read(WIDGET)
    cloud = read(CLOUD)
    routing = read(ROUTER)
    restore = read(RESTORE)
    apk = read(ACTIONS)
    blockers = []
    # A test proof is REQUIRED in addition to a code grep. Mark all unknown
    # dimensions NOT READY, rather than guessing from an app setting.
    if "SharedPreferences" in app or "persistLegacyFinanceBatch" in app:
        blockers.append("live_home_finance_still_writes_legacy")
    if "SharedPreferences" in widget or "WaffraLegacyWidgetCommitJournal" in widget:
        blockers.append("standalone_widget_still_writes_legacy")
    if "all_live_writers_not_yet_routed" in routing:
        blockers.append("runtime_encrypted_source_not_activated")
    if "read-only" in cloud.lower() or "does not invent missing finance" in cloud.lower():
        blockers.append("remote_to_local_atomic_restore_unverified")
    if "A future production cutover" in restore:
        blockers.append("portable_restore_not_proven_on_production_source")
    if "upload-artifact@v4" not in apk or "apksigner" not in apk:
        blockers.append("signed_apk_provenance_missing")
    blockers.extend([
        "real_two_device_recovery_not_attested",
        "physical_device_apk_install_and_launch_not_attested",
        "comprehensive_24_route_android_widget_evidence_not_attested",
    ])
    return {
        "releaseReady": not blockers,
        "reviewOnly": True,
        "headCommit": os.environ.get("GITHUB_SHA", "local-check"),
        "productionFirebaseDeployAttempted": False,
        "sourcePointerSwitched": False,
        "blockers": blockers,
    }

def main() -> int:
    evidence = inspect()
    filename = os.environ.get("WAFFRA_RELEASE_EVIDENCE", "")
    if filename:
        Path(filename).write_text(
            json.dumps(evidence, indent=2, sort_keys=True),
            encoding="utf-8",
        )
    print(json.dumps(evidence, indent=2, sort_keys=True))
    # IMPORTANT: Do not change to success while production blockers remain.
    return 0 if evidence["releaseReady"] else 1

if __name__ == "__main__":
    raise SystemExit(main())
