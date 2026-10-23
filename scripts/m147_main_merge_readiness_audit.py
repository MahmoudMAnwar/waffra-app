#!/usr/bin/env python3
"""M147: fail-closed, read-only audit of the final *review* PR against main.

Never merges, deploys, alters secrets, writes app databases, or publishes APKs.
All assertions concern repository lineage and changed-file scope only.
"""
from __future__ import annotations

import json
import os
import pathlib
import subprocess
import sys

APPROVED_MAIN = "965e25a0d62ed94401b112086edccb0a4fde790b"
APPROVED_M146 = "fdad2c55fcc0c6e0676cfa9e4121bee34dfcdc02"

EXPECTED_MAIN_DIFF = {
    ".github/workflows/android.yml",
    ".github/workflows/m131-backup-security-regression.yml",
    ".github/workflows/m132-backup-corruption-recovery.yml",
    ".github/workflows/m140-backup-integrity.yml",
    ".github/workflows/m146-main-safe-candidate.yml",
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/m146-main-safe-candidate.md",
    "docs/m147-final-main-merge-review.md",
    "scripts/m147_main_merge_readiness_audit.py",
    "lib/main.dart",
    "lib/waffra_secure_backup.dart",
    "test/m127_ui_tour_backup_acceptance_test.dart",
    "test/m131_backup_boundary_tamper_qa_test.dart",
    "test/m132_backup_corruption_recovery_negative_test.dart",
    "test/m140_backup_utf8_cross_archive_integrity_test.dart",
    "test/waffra_approved_ui_batch_test.dart",
    "test/waffra_secure_backup_test.dart",
}
NEW_M147_ONLY = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/m147-final-main-merge-review.md",
    "scripts/m147_main_merge_readiness_audit.py",
}


def git(*args: str) -> str:
    result = subprocess.run(
        ["git", *args], text=True, capture_output=True, check=True
    )
    return result.stdout.strip()


def paths_between(start: str, end: str) -> set[str]:
    return set(filter(None, git("diff", "--name-only", start, end).splitlines()))


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit("MERGE BLOCKED — " + message)


def main() -> None:
    # Checkout is pinned to pull_request.head.sha, not GitHub's synthetic
    # refs/pull/N/merge commit. Check the exact checkout against the event.
    actual_head = git("rev-parse", "HEAD")
    event_head = os.environ.get("REVIEW_HEAD_SHA", "").strip()
    require(bool(event_head) and actual_head == event_head,
            "checkout is not the reviewed head SHA")
    current_main = git("rev-parse", "refs/remotes/origin/main")
    require(current_main == APPROVED_MAIN,
            "main advanced since the reviewed baseline; refresh before merging")
    require(git("merge-base", current_main, actual_head) == current_main,
            "candidate is not a direct descendant of current main")
    require(git("merge-base", APPROVED_M146, actual_head) == APPROVED_M146,
            "M147 diverged from the M146 candidate with successful CI")

    actual_main_diff = paths_between(current_main, actual_head)
    actual_last_diff = paths_between(APPROVED_M146, actual_head)
    require(actual_main_diff == EXPECTED_MAIN_DIFF,
            "unexpected cumulative production diff: missing="
            + repr(sorted(EXPECTED_MAIN_DIFF - actual_main_diff))
            + " unexpected=" + repr(sorted(actual_main_diff - EXPECTED_MAIN_DIFF)))
    require(actual_last_diff == NEW_M147_ONLY,
            "M147 must add only review script, workflow, and instructions")
    require(not any(
        path.startswith(("lib/storage/", "firebase/", "native/"))
        for path in actual_main_diff
    ), "SQLCipher implementation, Firebase, or native widget changed")
    require(not any(
        path in actual_main_diff
        for path in ("pubspec.yaml", "pubspec.lock", "android/app/google-services.json")
    ), "dependencies or Firebase config were modified")

    behind, ahead = [int(n) for n in git(
        "rev-list", "--left-right", "--count", f"{current_main}...{actual_head}"
    ).split()]
    require(behind == 0, "candidate is behind main")
    require(0 < ahead <= 25, "candidate has an unexpectedly large commit history")

    plan = {
        "milestone": "M147",
        "head_sha": actual_head,
        "approved_m146_sha": APPROVED_M146,
        "main_baseline_sha": current_main,
        "main_merge_executed": False,
        "main_merge_authorized": False,
        "production_sqlcipher_cutover_authorized": False,
        "store_release_authorized": False,
        "changed_paths_against_main": sorted(actual_main_diff),
        "new_review_only_paths": sorted(actual_last_diff),
        "ahead_by": ahead,
        "behind_by": behind,
        "status": "REVIEWABLE_SAFE_SCOPE_NOT_MERGE_OR_RELEASE_APPROVAL",
        "still_required": [
            "Full M147 same-head test and Android compile CI must pass.",
            "Human diff review and explicit approval before main merge.",
            "Signed physical-device smoke including Firebase Google Sign-In.",
            "Legacy backup restore and clean-install device verification.",
            "Privacy, data safety, crash reporting and store checks before release.",
            "Do not migrate user data or activate production SQLCipher.",
        ],
        "proposed_safe_merge_method": "squash via reviewed PR after explicit approval",
        "proposed_code_rollback": (
            "Create a new revert PR for the resulting squash-merge commit; "
            "run the same CI and device checks before deployment. "
            "Git revert does NOT roll back user data or cloud changes."
        ),
    }
    output = pathlib.Path("build/m147-final-review-report.json")
    output.parent.mkdir(exist_ok=True, parents=True)
    output.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n",
                      encoding="utf-8")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as file:
            file.write(
                "## M147 main candidate: scope accepted, merge not authorized\n\n"
                f"- Main: `{current_main[:12]}`, candidate: `{actual_head[:12]}`\n"
                f"- Changed files: {len(actual_main_diff)}, "
                f"ahead {ahead}, behind {behind}\n"
                "- No experimental SQLCipher, Firebase or native Widget paths changed.\n"
                "- **Still Draft; manual signed-device and explicit merge approval required.**\n"
            )
    print(json.dumps(plan, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
