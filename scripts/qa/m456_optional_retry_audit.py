"""M456: fail closed on real CI regressions, not a deliberately skipped retry.

M410 is an optional *workflow_run* response to a failed Android UI job.
On healthy main pushes it starts a run but its conditional job is skipped;
GitHub reports the whole run as "skipped". A signed APK must NOT be
blocked by that intentional no-op. Every missing required workflow,
other skipped workflow, cancelled/error/timed-out run, and actual failure
still blocks the release. This module only classifies READ-ONLY results.
"""
from __future__ import annotations

from collections.abc import Mapping
from typing import Any

OPTIONAL_NOOP_SKIP = frozenset({
    "M410 Bounded Failed Android UI Job Retry",
})


def classify_same_sha_checks(
    checks: Mapping[str, Mapping[str, Any]],
    expected: set[str],
) -> tuple[list[str], list[str], list[tuple[str, Any, Any]]]:
    """Return missing, in-progress and forbidden completed conclusions."""
    missing = sorted(expected - checks.keys())
    pending: list[str] = []
    failed: list[tuple[str, Any, Any]] = []
    for name, run in checks.items():
        if run["status"] != "completed":
            pending.append(name)
            continue
        conclusion = run["conclusion"]
        if conclusion == "success":
            continue
        if name in OPTIONAL_NOOP_SKIP and conclusion == "skipped" and name not in expected:
            continue
        failed.append((name, conclusion, run.get("html_url")))
    return missing, pending, failed
