#!/usr/bin/env python3
"""M174: immutable review of the additive main-SHA CI work, not a release approval."""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess

CHANGED_ONLY = {
    ".github/workflows/m147-final-main-review-gate.yml",
    ".github/workflows/m174-main-sha-postmerge.yml",
    "scripts/qa/m174_main_scope_review.py",
    "docs/qa/m174-main-sha-postmerge.md",
}


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], check=True, capture_output=True, text=True,
    ).stdout.strip()


def verify() -> dict:
    head = git("rev-parse", "HEAD")
    expected_head = os.environ.get("REVIEW_HEAD_SHA", "").strip()
    if not expected_head or head != expected_head:
        raise SystemExit("M174 BLOCKED: checkout SHA differs from reviewed head")
    main = git("rev-parse", "refs/remotes/origin/main")
    if git("merge-base", main, head) != main:
        raise SystemExit("M174 BLOCKED: PR head is not descended from current main")
    changed = set(filter(None, git("diff", "--name-only", main, head).splitlines()))
    if changed != CHANGED_ONLY:
        raise SystemExit("M174 BLOCKED: unexpected file scope. missing="
                         + repr(sorted(CHANGED_ONLY - changed))
                         + "; extra=" + repr(sorted(changed - CHANGED_ONLY)))
    return {
        "milestone": "M174",
        "reviewedHeadSha": head,
        "mainBaselineSha": main,
        "changedPaths": sorted(changed),
        "containsProductCodeChanges": False,
        "productionSqlCipherActivated": False,
        "userDataMigrationAttempted": False,
        "realDeviceCertification": False,
        "releaseAuthorized": False,
        "status": "QA_INFRA_ONLY_NOT_PRODUCTION_APPROVAL",
    }


if __name__ == "__main__":
    report = verify()
    artifact = Path("build/m147-final-review-report.json")
    artifact.parent.mkdir(exist_ok=True, parents=True)
    artifact.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
