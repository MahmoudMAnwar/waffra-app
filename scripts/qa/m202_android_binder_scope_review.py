#!/usr/bin/env python3
"""M202 exact-SHA source/diff and NO-GO review; not an activation script."""
import json
import os
import subprocess
from pathlib import Path

FILES = {
    ".github/workflows/m147-final-main-review-gate.yml",
    ".github/workflows/m202-android-binder-dryrun.yml",
    "docs/qa/m202-android-binder-evidence.md",
    "integration_test/m202_existing_source_home_widget_android_test.dart",
    "scripts/qa/m202_android_binder_scope_review.py",
}

def git(*args):
    return subprocess.run(["git", *args], capture_output=True,
                          text=True, check=True).stdout.strip()

def main():
    head = git("rev-parse", "HEAD")
    expected = os.environ.get("REVIEW_HEAD_SHA", "")
    if not expected or expected != head:
        raise SystemExit("M202 BLOCKED: wrong head SHA")
    base = git("rev-parse", "refs/remotes/origin/main")
    if git("merge-base", base, head) != base:
        raise SystemExit("M202 BLOCKED: review branch is behind main")
    changed = set(filter(None, git("diff", "--name-only", base, head).splitlines()))
    if changed != FILES:
        raise SystemExit("M202 BLOCKED: unexpected changed files: " +
                         repr(sorted(changed ^ FILES)))
    test = Path("integration_test/m202_existing_source_home_widget_android_test.dart").read_text()
    workflow = Path(".github/workflows/m202-android-binder-dryrun.yml").read_text()
    guide = Path("docs/qa/m202-android-binder-evidence.md").read_text()
    binder = Path("lib/storage/waffra_production_finance_authority_binding.dart").read_text()
    release = Path("lib/storage/waffra_production_cutover_release_gate.dart").read_text()
    for marker in (
        "WaffraProductionFinanceAuthorityBinding.bind(",
        "WaffraFinanceRoute.widgetStartup",
        "WaffraFinanceRoute.appStartup",
        "WaffraFinanceRoute.widgetSmsConfirmedSave",
        "WaffraFinanceRoute.dashboardRead",
        "bad-key", # left intentionally NOT a source test: review marker below
    )[:-1]:
        if marker not in test:
            raise SystemExit("M202 BLOCKED: test omitted " + marker)
    for marker in (
        "wrong-test-key",
        "throwsStateError",
        "source: WaffraProductionFinanceSource.encryptedRoutingRequired",
        "directory.delete(recursive: true)",
        "getTemporaryDirectory()",
    ):
        if marker not in test:
            raise SystemExit("M202 BLOCKED: negative/isolated test missing " + marker)
    for marker in (
        "reactivecircus/android-emulator-runner@v2",
        "m202_existing_source_home_widget_android_test.dart",
        "real_24_route_attestation_count",
        "production_source_transition",
        "physical_device_witness_count",
    ):
        if marker not in workflow:
            raise SystemExit("M202 BLOCKED: emulator or truthful output missing " + marker)
    if "NO-GO" not in guide or "zero independently proven live finance routes" not in guide:
        raise SystemExit("M202 BLOCKED: acceptance limits undocumented")
    for marker in (
        "sourceGuard.inspect()", "if (evidence == null)",
        "FileSystemEntity.type(path.path, followLinks: false)",
        "WaffraEncryptedStore.openAt(path, key: key)",
    ):
        if marker not in binder:
            raise SystemExit("M202 BLOCKED: binder fail-closed contract changed")
    if "bool get automaticallyActivateSqlCipher => false;" not in release:
        raise SystemExit("M202 BLOCKED: automatic finance cutover enabled")
    output = Path("build/m147-final-review-report.json")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps({
        "exact_review_sha": head,
        "diff": sorted(changed),
        "emulator_run_status": "NOT_ASSERTED_BY_SCOPE_AUDIT",
        "real_physical_devices": 0,
        "live_route_24_witnesses": 0,
        "production_finance_activated": False,
        "go_no_go": "NO_GO"
    }, indent=2) + "\n")
    print("M202 exact-SHA test-only scope approved; production NO-GO")

if __name__ == "__main__":
    main()
