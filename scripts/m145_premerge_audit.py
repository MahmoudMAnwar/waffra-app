#!/usr/bin/env python3
"""M145: read-only sibling-PR integration and main-merge blocker audit.

Runs inside a PR checkout. Does not write to git, SQLCipher, app data or main.
A passing audit means the two QA branches combine cleanly, NOT release-ready.
"""
from __future__ import annotations

import json
import os
import pathlib
import subprocess

BASE = "test/m143-sqlcipher-confirmation-input-freeze-qa"
LEFT = "test/m144-sqlcipher-two-connection-writer-lock-qa"
RIGHT = "test/m144-writer-gate-hostile-path-recovery-qa"
EXPECTED = {
    BASE: "11f9eb500963fcf81d46070f3ef4773d88647140",
    LEFT: "d1218ed66ddcab2c9bc53fb8939b3c7e348fa28a",
    RIGHT: "b0b7fd5dfebecc58de18e14eb700641816901e57",
}
LEFT_FILES = {
    "test/storage/m144_sqlcipher_two_connection_writer_gate_test.dart",
    ".github/workflows/m144-two-connection-writer-gate.yml",
}
RIGHT_FILES = {
    "test/storage/m144_writer_gate_hostile_path_recovery_test.dart",
    ".github/workflows/m144-writer-gate-hostile-path-qa.yml",
}
ALLOWED_M145 = ("test/", "docs/", "scripts/", ".github/workflows/")


def git(*args: str) -> str:
    process = subprocess.run(
        ["git", *args], check=True, capture_output=True, text=True
    )
    return process.stdout.strip()


def ref(name: str) -> str:
    return f"refs/remotes/origin/{name}"


def files_between(base: str, head: str) -> set[str]:
    return set(filter(None, git("diff", "--name-only", base, head).splitlines()))


def main() -> None:
    refs = ["main", BASE, LEFT, RIGHT]
    # Read remote refs, do not update tracked files or create commits.
    git(
        "fetch", "--no-tags", "origin",
        *(f"+refs/heads/{name}:{ref(name)}" for name in refs),
    )
    for name, expected in EXPECTED.items():
        actual = git("rev-parse", ref(name))
        if actual != expected:
            raise SystemExit(
                f"BLOCKED: {name} advanced from sealed review SHA {expected} "
                f"to {actual}; re-audit before integration"
            )

    ancestor = git("merge-base", ref(LEFT), ref(RIGHT))
    if ancestor != EXPECTED[BASE]:
        raise SystemExit("BLOCKED: M144 siblings no longer share exact M143 base")

    left_paths = files_between(ref(BASE), ref(LEFT))
    right_paths = files_between(ref(BASE), ref(RIGHT))
    if left_paths != LEFT_FILES or right_paths != RIGHT_FILES:
        raise SystemExit(
            "BLOCKED: sibling changed-file lists differ from inspected "
            f"QA-only baselines: left={sorted(left_paths)} right={sorted(right_paths)}"
        )
    if left_paths & right_paths:
        raise SystemExit(f"BLOCKED: overlapping files: {sorted(left_paths & right_paths)}")

    # GitHub checkout of the M145 PR has already merged the reviewed
    # M144 #151 test from the sibling branch onto the #152 branch.
    integration_paths = files_between(ref(RIGHT), "HEAD")
    if not LEFT_FILES.intersection(integration_paths):
        raise SystemExit("BLOCKED: missing two-connection test in M145 preview")
    if any(not path.startswith(ALLOWED_M145) for path in integration_paths):
        raise SystemExit(
            f"BLOCKED: unexpected production file in M145: {sorted(integration_paths)}"
        )
    copied = pathlib.Path(
        "test/storage/m144_sqlcipher_two_connection_writer_gate_test.dart"
    ).read_bytes()
    original = subprocess.run(
        ["git", "show", f"{ref(LEFT)}:test/storage/m144_sqlcipher_two_connection_writer_gate_test.dart"],
        check=True, capture_output=True,
    ).stdout
    if copied != original:
        raise SystemExit("BLOCKED: integrated two-connection test differs from #151")

    # merge-tree computes the prospective combined tree without creating a
    # merge commit or updating either PR, main, the index or working files.
    combined_tree = git("merge-tree", "--write-tree", ref(LEFT), ref(RIGHT))
    behind, ahead = (
        int(part) for part in git(
            "rev-list", "--left-right", "--count", f"{ref('main')}...{ref(RIGHT)}"
        ).split()
    )
    blockers = [
        "No explicit approval to merge or activate production SQLCipher.",
        "Real-device backup/restore, Home/Widget writer and migration evidence required.",
        "QA-only sibling integration does not certify the larger SQLCipher stack.",
    ]
    if behind > 0 or ahead > 20:
        blockers.append(
            f"SQLCipher branch is not a small main fast-forward "
            f"(main-only commits={behind}; SQLCipher-only commits={ahead})."
        )

    report = {
        "milestone": "M145",
        "result": "QA_SIBLINGS_INTEGRATE_CLEANLY_MAIN_MERGE_BLOCKED",
        "main_merge_authorized": False,
        "production_sqlcipher_activation_authorized": False,
        "branches": EXPECTED,
        "common_ancestor": ancestor,
        "merge_preview_tree": combined_tree,
        "left_paths": sorted(left_paths),
        "right_paths": sorted(right_paths),
        "m145_paths": sorted(integration_paths),
        "main_divergence": {"main_only": behind, "sqlcipher_only": ahead},
        "remaining_blockers": blockers,
    }
    path = pathlib.Path("build/m145-review-report.json")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as file:
            file.write(
                "## M145: QA siblings merge preview passed; main merge BLOCKED\n\n"
                f"- Sealed M143 base: `{ancestor[:12]}`\n"
                f"- Independent M144 tests: {len(left_paths)} + {len(right_paths)} files, no overlaps\n"
                f"- Safe merge tree: `{combined_tree[:12]}` (not committed)\n"
                f"- main divergence: {behind} main-only / {ahead} SQLCipher-only commits\n"
                "- **No permission to merge into main or turn on SQLCipher.**\n"
            )
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
