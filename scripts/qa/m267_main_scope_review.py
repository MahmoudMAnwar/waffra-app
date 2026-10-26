#!/usr/bin/env python3
"""M267 exact-main Python/QA-only scope review. Always NO-GO for cutover."""
from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path


def git(*argv: str) -> str:
    return subprocess.check_output(["git", *argv], text=True).strip()


def require(value: bool, reason: str) -> None:
    if not value:
        raise SystemExit("M267 BLOCKED: " + reason)


def main() -> None:
    head = git("rev-parse", "HEAD")
    expected = os.environ.get("REVIEW_HEAD_SHA")
    require(bool(expected) and head == expected, "reviewed SHA mismatch")
    base = git("rev-parse", "refs/remotes/origin/main")
    require(git("merge-base", head, base) == base,
            "reviewed branch is not based on current main")
    files = set(filter(None, git(
        "diff", "--name-only", base + "...HEAD").splitlines()))
    allowed = {
        "scripts/qa/m267_signed_two_phone_apk_probe.py",
        "test/qa/m267_signed_two_phone_apk_probe_test.py",
        "docs/qa/m267-two-physical-signed-apk-identity.md",
        "scripts/qa/m267_main_scope_review.py",
        ".github/workflows/m267-android-exact-apk-identity.yml",
        ".github/workflows/m147-final-main-review-gate.yml",
    }
    require(files == allowed, "unexpected/missing paths: " + str(sorted(files ^ allowed)))
    source = Path("scripts/qa/m267_signed_two_phone_apk_probe.py").read_text()
    for guard in (
        "m189_physical_device_source_probe",
        "Verified using v2 scheme",
        "Verified using v3 scheme",
        "source_backed_24_routes_attested",
        "production_release_allowed",
        "two_phone_sqlcipher_restore_attested",
        "IDENTITY_ASSET",
        "trusted_signer",
    ):
        require(guard in source, "APK or NO-GO guard missing: " + guard)
    require("production_release_allowed\": False" in source,
            "script may declare false production release approval")
    workflow = Path(".github/workflows/m267-android-exact-apk-identity.yml").read_text()
    require("m267_signed_two_phone_apk_probe_test.py" in workflow,
            "negative identity regression is not enforced")
    require("m267_main_scope_review.py" in workflow,
            "same-main scope review is not enforced")
    release = Path("lib/storage/waffra_production_cutover_release_gate.dart").read_text()
    require("bool get automaticallyActivateSqlCipher => false;" in release,
            "SQLCipher activation must remain blocked")
    evidence = {
        "milestone": "M267",
        "reviewed_sha": head,
        "base_main_sha": base,
        "changed_files": sorted(files),
        "real_android_handsets_tested_in_ci": 0,
        "live_finance_route_attestations": 0,
        "production_sqlcipher_activated": False,
        "release_ready": False,
        "status": "EXACT_APK_QA_TOOL_ONLY_NO_GO",
    }
    path = Path("build/m147-final-review-report.json")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(evidence, indent=2) + "\n")
    print(json.dumps(evidence, indent=2))


if __name__ == "__main__":
    main()
