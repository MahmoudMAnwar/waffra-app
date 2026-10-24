#!/usr/bin/env python3
"""M189 exact-HEAD source and two-Android QA gate, NOT physical attestation."""
from __future__ import annotations
import json
import os
from pathlib import Path
import subprocess

FILES = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/m189-two-physical-android-acceptance.md",
    "scripts/qa/m189_physical_device_source_probe.py",
    "scripts/qa/m189_physical_scope_review.py",
    "test/qa/m189_physical_device_source_probe_test.py",
}


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], check=True, capture_output=True, text=True,
    ).stdout.strip()


def main() -> None:
    head = git("rev-parse", "HEAD")
    if head != os.environ.get("REVIEW_HEAD_SHA", "").strip():
        raise SystemExit("M189: stale or missing exact PR SHA")
    base = git("rev-parse", "refs/remotes/origin/main")
    if git("merge-base", base, head) != base:
        raise SystemExit("M189: main advanced, rebuild or review needed")
    paths = set(filter(None, git("diff", "--name-only", base, head).splitlines()))
    if paths != FILES:
        raise SystemExit("M189: unexpected source scope " + repr(sorted(paths ^ FILES)))

    probe = Path("scripts/qa/m189_physical_device_source_probe.py").read_text()
    tests = Path("test/qa/m189_physical_device_source_probe_test.py").read_text()
    docs = Path("docs/qa/m189-two-physical-android-acceptance.md").read_text()
    source = Path("lib/storage/waffra_production_finance_source_guard.dart").read_text()
    release = Path("lib/storage/waffra_production_cutover_release_gate.dart").read_text()
    for marker in [
        "len(names) != 24 or names != REQUIRED_ROUTES",
        "ro.kernel.qemu",
        "ro.hardware",
        "Exactly two distinct online, authorized Android devices required.",
        "An emulator/virtualized Android cannot satisfy",
        "package_present",
        "route_execution_witnesses",
        '"store_publication_permitted": False',
        '"backup_restore_across_two_real_devices_attested": False',
        '"human_release_approval": False',
        "PHYSICAL_HARDWARE_DETECTED_ONLY_RELEASE_NO_GO",
        "os.chmod(args.output, 0o600)",
    ]:
        if marker not in probe:
            raise SystemExit("M189: missing read-only Android fail-closed witness: " + marker)
    for marker in [
        "two_mock_phones_are_not_release_certification",
        "same_serial_or_single_device_cannot_count_as_two",
        "emulator_or_virtual_android_is_never_physical",
        "unsupported_os_or_uninstalled_apk_refuses_evidence",
        "device_probes_cannot_leak_raw_serial_or_read_finance",
    ]:
        if marker not in tests:
            raise SystemExit("M189: missing negative QA test: " + marker)
    for marker in [
        "Google Play intentionally remains the LAST phase",
        "NO-GO", "24/24 live routes",
        "The CLI checks", "hardware witness harness only",
    ]:
        if marker not in docs:
            raise SystemExit("M189: missing scope/release disclaimer: " + marker)
    if "all_live_writers_not_yet_routed" not in source or (
        "bool get automaticallyActivateSqlCipher => false;" not in release
    ):
        raise SystemExit("M189: production source guard was weakened")

    report = {
        "milestone": "M189",
        "head": head,
        "base_main": base,
        "changes": sorted(paths),
        "physical_devices_attested_by_ci": False,
        "all_24_runtime_finance_routes_attested": False,
        "two_real_device_restore_attested": False,
        "production_sqlcipher_activated": False,
        "google_play_last_phase": True,
        "status": "M189_PHYSICAL_PROBE_CI_ONLY_NO_GO",
    }
    output = Path("build/m147-final-review-report.json")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
