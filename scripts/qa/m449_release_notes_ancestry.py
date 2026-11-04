#!/usr/bin/env python3
"""Fail-closed ancestry gate shared by PR review and signed main APK publishing.

A changelog in the Git tree must be reviewed *after* the latest application
change. A successful Flutter/Android build is not permission to publish stale
release notes. This gate performs no writes and uses Git ancestry, not clocks.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

NOTES_PATH = "docs/release/WAFFRA_APPROVED_CHANGES.txt"
# Include all application/Android/asset changes, not just main.dart or storage.
APP_PATHS = ("lib/", "android/app/", "assets/", "pubspec.yaml")


def git(*args: str) -> str:
    result = subprocess.run(
        ["git", *args], text=True, capture_output=True, check=False
    )
    if result.returncode:
        raise RuntimeError(
            "Release provenance Git command failed: "
            + " ".join(args) + ": " + result.stderr[:350]
        )
    return result.stdout.strip()


def inspect_release_notes() -> tuple[str, str]:
    notes = Path(NOTES_PATH)
    if not notes.is_file() or not notes.stat().st_size:
        raise RuntimeError("Missing approved release notes: " + NOTES_PATH)
    # Verify both commits belong to this exact checkout's history.
    notes_commit = git("log", "-1", "--format=%H", "--", NOTES_PATH)
    app_commit = git("log", "-1", "--format=%H", "--", *APP_PATHS)
    if not notes_commit or not app_commit:
        raise RuntimeError("Missing release notes or application history")
    result = subprocess.run(
        ["git", "merge-base", "--is-ancestor", app_commit, notes_commit],
        capture_output=True, text=True, check=False,
    )
    if result.returncode:
        raise RuntimeError(
            "Approved release notes are older than app-code changes. "
            f"Update {NOTES_PATH} after reviewing the latest application "
            f"changes. App={app_commit[:12]} notes={notes_commit[:12]}. "
            "Block this PR BEFORE signed main APK publishing."
        )
    return app_commit, notes_commit


def main() -> int:
    try:
        current = git("rev-parse", "HEAD")
        app, notes = inspect_release_notes()
    except (OSError, RuntimeError) as exc:
        print("BLOCKED M449 release-note ancestry: " + str(exc), file=sys.stderr)
        return 1
    print(
        "PASS M449: reviewed release notes cover latest app/Android/asset "
        f"revision. HEAD={current[:12]} app={app[:12]} notes={notes[:12]}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
