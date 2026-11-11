#!/usr/bin/env python3
"""M645: prepare *reviewed* notes after committed source, before PR push.

Never fabricate product claims from filenames. Human supplies the summary.
No untrusted PR workflow writes to the branch; M449 ancestry remains mandatory.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

NOTES = "docs/release/WAFFRA_APPROVED_CHANGES.txt"
CHECK = "scripts/qa/m449_release_notes_ancestry.py"
APP_PATHS = ("lib/", "android/app/", "assets/", "pubspec.yaml")


class NotesPreparationError(ValueError):
    pass


def git(*args: str) -> str:
    command = subprocess.run(
        ["git", *args], capture_output=True, text=True, check=False)
    if command.returncode:
        raise NotesPreparationError(
            "Git operation failed: " + " ".join(args) + ": "
            + command.stderr[:250])
    return command.stdout.strip()


def check_m449() -> None:
    result = subprocess.run(
        [sys.executable, CHECK], text=True, capture_output=True, check=False)
    if result.stdout:
        print(result.stdout.strip())
    if result.returncode:
        raise NotesPreparationError(
            "Existing M449 freshness gate not green: " + result.stderr[:350])


def validate_review(issue: int | None, pr: int | None, summary: str | None) -> str:
    if issue is None or issue < 1 or pr is None or pr < 1:
        raise NotesPreparationError("Positive Issue and PR numbers are required")
    clean = (summary or "").strip()
    if (len(clean) < 15 or len(clean) > 600
            or "\n" in clean or "\r" in clean
            or re.search(r"\b(TODO|TBD|PLACEHOLDER|lorem ipsum)\b", clean, re.I)):
        raise NotesPreparationError(
            "Specific owner-reviewed 15-600 character single-line summary required")
    return clean


def plan() -> tuple[str, str, list[str]] | None:
    if not Path(NOTES).is_file():
        raise NotesPreparationError("Missing current release notes")
    for pathset in (APP_PATHS, (NOTES,)):
        if git("status", "--porcelain", "--", *pathset):
            raise NotesPreparationError(
                "Commit all app changes first; do not overwrite unreviewed notes")
    app_sha = git("log", "-1", "--format=%H", "--", *APP_PATHS)
    note_sha = git("log", "-1", "--format=%H", "--", NOTES)
    if not re.fullmatch(r"[0-9a-f]{40}", app_sha) or not re.fullmatch(
            r"[0-9a-f]{40}", note_sha):
        raise NotesPreparationError("Missing verifiable app or notes SHA")
    if subprocess.run(
            ["git", "merge-base", "--is-ancestor", app_sha, "HEAD"],
            capture_output=True, check=False).returncode:
        raise NotesPreparationError("App source SHA is not in this branch")
    changed = git("diff", "--name-only", note_sha + "..HEAD", "--", *APP_PATHS)
    paths = sorted(set(changed.splitlines())) if changed else []
    if not paths:
        print("M645 UP TO DATE: no new app changes after last reviewed notes")
        check_m449()
        return None
    return app_sha, note_sha, paths


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--issue", type=int)
    parser.add_argument("--pr", type=int)
    parser.add_argument("--summary", help="Factual owner-reviewed change summary")
    parser.add_argument("--commit", action="store_true",
                        help="Commit only approved notes and run strict M449")
    parser.add_argument("--verify-only", action="store_true",
                        help="Run original M449 without making changes")
    args = parser.parse_args()
    if args.verify_only:
        check_m449()
        return 0
    summary = validate_review(args.issue, args.pr, args.summary)
    item = plan()
    if item is None:
        return 0
    app_sha, old_notes_sha, changed = item
    entry = (
        "\n[M449 REVIEWED UPDATE — ISSUE #" + str(args.issue)
        + " — PR #" + str(args.pr) + "]\n"
        + "- Reviewed source SHA: " + app_sha + "\n"
        + "- Approved change: " + summary + "\n"
        + "- Changed production paths: " + ", ".join(changed) + "\n"
        + "- Verification: exact-head CI and physical Android evidence remain "
        + "separate, not approved merely by these notes.\n"
    )
    if not args.commit:
        print("M645 PREVIEW ONLY: no file or commit changes")
        print("Prior notes commit: " + old_notes_sha)
        print(entry)
        return 0
    target = Path(NOTES)
    target.write_text(
        target.read_text(encoding="utf-8").rstrip("\n") + "\n" + entry,
        encoding="utf-8")
    git("add", "--", NOTES)
    git("commit", "-m", "docs(M449): review Issue #"
        + str(args.issue) + " PR #" + str(args.pr) + " source " + app_sha[:12])
    check_m449()
    print("M645 COMMITTED: approved notes cover source SHA " + app_sha)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, NotesPreparationError) as exc:
        print("M645 BLOCKED: " + str(exc), file=sys.stderr)
        raise SystemExit(1)
