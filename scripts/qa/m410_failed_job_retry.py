#!/usr/bin/env python3
"""M410: retry a single *infrastructure* failure, never a failed assertion.

This script runs only from the repository's trusted default branch in a
workflow_run event. No PR branch code is executed with write permissions.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

WORKFLOW = "M274 Production UI Journeys and Golden Screenshot Review"
JOB = "android-emulator-ui-taps"
INFRA = (
    "registerService: (-32000) Service connection disposed",
    "Failed to start Dart Development Service",
    "adb: device offline",
)
ASSERTIONS = re.compile(r"(?m)^\s*(Expected:|Actual:|Test failed\.)")
MAX_LOG_BYTES = 2_000_000


def candidate(event: dict, jobs: list[dict], log: str,
              current_sha: str) -> tuple[int | None, str]:
    run = event.get("workflow_run") or {}
    repository = (event.get("repository") or {}).get("full_name")
    head_repo = (run.get("head_repository") or {}).get("full_name")
    if (run.get("name") != WORKFLOW or run.get("event") != "pull_request"
            or run.get("conclusion") != "failure"):
        return None, "not an eligible failed PR workflow"
    if run.get("run_attempt") != 1:
        return None, "retry already attempted; do not loop"
    if not repository or head_repo != repository:
        return None, "refusing untrusted fork or missing repository"
    sha = run.get("head_sha")
    if not isinstance(sha, str) or not re.fullmatch(r"[0-9a-f]{40}", sha):
        return None, "missing full commit SHA"
    if current_sha != sha:
        return None, "obsolete branch HEAD; never retry stale code"
    if not isinstance(jobs, list):
        return None, "job data unavailable"
    failed = [j for j in jobs if j.get("conclusion") == "failure"]
    if len(failed) != 1 or failed[0].get("name") != JOB:
        return None, "not exactly one known failing Android UI job"
    job_id = failed[0].get("id")
    if not isinstance(job_id, int) or job_id <= 0:
        return None, "invalid job ID"
    if ASSERTIONS.search(log):
        return None, "actual application assertion failed; code review needed"
    if not any(marker in log for marker in INFRA):
        return None, "no proven retryable infrastructure signature"
    return job_id, "one bounded transient-infrastructure retry"


def gh_api(endpoint: str, post: bool = False) -> str:
    cmd = ["gh", "api"]
    if post:
        cmd += ["-X", "POST"]
    cmd.append(endpoint)
    result = subprocess.run(cmd, check=True, capture_output=True)
    return result.stdout.decode("utf-8", errors="replace")


def main() -> int:
    event_path = os.environ.get("GITHUB_EVENT_PATH", "")
    if not event_path:
        raise RuntimeError("No GitHub workflow event; fail closed")
    event = json.loads(Path(event_path).read_text(encoding="utf-8"))
    run = event.get("workflow_run") or {}
    if (run.get("name") != WORKFLOW or run.get("event") != "pull_request"
            or run.get("conclusion") != "failure"
            or run.get("run_attempt") != 1):
        print("M410 SKIP: event not eligible")
        return 0
    repo = (event.get("repository") or {}).get("full_name", "")
    head = run.get("head_branch", "")
    if not (isinstance(repo, str) and re.fullmatch(r"[\w.-]+/[\w.-]+", repo)
            and isinstance(head, str)
            and re.fullmatch(r"[\w./-]+", head)
            and ".." not in head and len(head) < 220):
        print("M410 SKIP: unsafe repository/branch")
        return 0
    if (run.get("head_repository") or {}).get("full_name") != repo:
        print("M410 SKIP: untrusted fork")
        return 0

    from urllib.parse import quote
    # HEAD must still match this exact run; ignore a superseded SHA.
    ref = json.loads(gh_api(f"repos/{repo}/git/ref/heads/{quote(head, safe='/')}"))
    current_sha = (ref.get("object") or {}).get("sha", "")
    run_id = run.get("id")
    if not isinstance(run_id, int) or run_id <= 0:
        print("M410 SKIP: invalid run ID")
        return 0
    response = json.loads(gh_api(
        f"repos/{repo}/actions/runs/{run_id}/jobs?filter=latest&per_page=100"))
    jobs = response.get("jobs") or []
    if response.get("total_count", 101) > 100:
        print("M410 SKIP: job pagination required")
        return 0
    failed = [job for job in jobs if job.get("conclusion") == "failure"]
    if len(failed) != 1 or failed[0].get("name") != JOB:
        print("M410 SKIP: not exactly one M274 Android emulator failure")
        return 0
    job_id = failed[0].get("id")
    if not isinstance(job_id, int):
        print("M410 SKIP: invalid failed job")
        return 0
    log = gh_api(f"repos/{repo}/actions/jobs/{job_id}/logs")
    if len(log.encode("utf-8")) > MAX_LOG_BYTES:
        print("M410 SKIP: logs exceed safety limit")
        return 0
    selected, reason = candidate(event, jobs, log, current_sha)
    print(f"M410: {reason}")
    if selected is None:
        return 0
    # Re-run ONE job on the SAME SHA; no new commit or blanket 42-workflow run.
    gh_api(f"repos/{repo}/actions/jobs/{selected}/rerun", post=True)
    print(f"M410 RETRY: job {selected}, run {run_id}, attempt 2 maximum")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, OSError, subprocess.CalledProcessError, RuntimeError) as exc:
        print(f"M410 BLOCKED: cannot certify or retry safely: {exc}", file=sys.stderr)
        raise SystemExit(1)
