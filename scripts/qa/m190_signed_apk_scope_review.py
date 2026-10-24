#!/usr/bin/env python3
"""M190 exact-SHA five-file signed APK preflight review; release always NO-GO."""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess

FILES = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/m190-signed-apk-preflight-no-go.md",
    "scripts/qa/m190_signed_apk_preflight.py",
    "scripts/qa/m190_signed_apk_scope_review.py",
    "test/qa/m190_signed_apk_preflight_test.py",
}


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], check=True, capture_output=True, text=True,
    ).stdout.strip()


def main() -> None:
    head = git("rev-parse", "HEAD")
    if head != os.environ.get("REVIEW_HEAD_SHA", "").strip():
        raise SystemExit("M190: exact reviewed HEAD SHA missing or stale")
    base = git("rev-parse", "refs/remotes/origin/main")
    if git("merge-base", base, head) != base:
        raise SystemExit("M190: main advanced, rebase and retest before merge")
    files = set(filter(None, git("diff", "--name-only", base, head).splitlines()))
    if files != FILES:
        raise SystemExit("M190: unexpected source scope " + repr(sorted(files ^ FILES)))

    preflight = Path("scripts/qa/m190_signed_apk_preflight.py").read_text()
    tests = Path("test/qa/m190_signed_apk_preflight_test.py").read_text()
    docs = Path("docs/qa/m190-signed-apk-preflight-no-go.md").read_text()
    source = Path("lib/storage/waffra_production_finance_source_guard.dart").read_text()
    release = Path("lib/storage/waffra_production_cutover_release_gate.dart").read_text()
    for marker in (
        "expected_apk_sha256", "expected_cert_sha256", "apksigner",
        "aapt", "MAX_APK_BYTES", "CN", "Android Debug",
        "Verified using v(?:2|3) scheme",
        '"physical_android_devices_verified": False',
        '"device_installed_apk_byte_identity_verified": False',
        '"live_finance_routes_24_of_24_verified": False',
        '"production_sqlcipher_cutover_permitted": False',
        '"google_play_publication_permitted": False',
        "SIGNED_APK_LOCAL_PREFLIGHT_ONLY_RELEASE_NO_GO",
        "os.chmod(args.output, 0o600)",
    ):
        if marker not in preflight:
            raise SystemExit("M190: missing signer or NO-GO guard " + marker)
    for marker in (
        "test_wrong_apk_sha_refuses_even_if_signer_is_correct",
        "test_wrong_signer_pin_refuses",
        "test_debug_certificate_refuses",
        "test_v1_only_signature_refuses",
        "test_multiple_signers_refuse",
        "test_unexpected_package_refuses",
        "test_matching_pinned_apk_is_still_release_no_go",
    ):
        if marker not in tests:
            raise SystemExit("M190: missing negative signing test " + marker)
    if "Google Play remains the final phase" not in docs or (
        "not a real APK" not in docs or "NO-GO" not in docs
    ):
        raise SystemExit("M190: missing physical-release disclaimers")
    if "all_live_writers_not_yet_routed" not in source or (
        "bool get automaticallyActivateSqlCipher => false;" not in release
    ):
        raise SystemExit("M190: production source guard was weakened")

    report = {
        "milestone": "M190",
        "head": head,
        "base_main": base,
        "changed_files": sorted(files),
        "actual_signed_apk_verified_in_ci": False,
        "real_physical_android_devices_verified": False,
        "finance_routes_24_of_24_verified": False,
        "sqlcipher_production_activated": False,
        "google_play_publication_permitted": False,
        "status": "M190_SIGNED_APK_SOURCE_ONLY_RELEASE_NO_GO",
    }
    output = Path("build/m147-final-review-report.json")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
