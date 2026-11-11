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
    # Manual-only trusted recovery: the 80+ Skipped workflow_run notifications
    # must not create new Actions runs just to reject a successful M274 job.
    if os.environ.get("GITHUB_EVENT_NAME") != "workflow_dispatch":
        raise RuntimeError("M410 requires explicit authorized manual dispatch")
    event_path = os.environ.get("GITHUB_EVENT_PATH", "")
    raw = os.environ.get("SOURCE_M274_RUN_ID", "").strip()
    if not event_path or not re.fullmatch(r"[1-9][0-9]{0,14}", raw):
        raise RuntimeError("Missing/invalid numeric failed M274 workflow run ID")
    event = json.loads(Path(event_path).read_text(encoding="utf-8"))
    repo = (event.get("repository") or {}).get("full_name", "")
    if (not isinstance(repo, str)
            or not re.fullmatch(r"[\\w.-]+/[\\w.-]+", repo)
            or repo != os.environ.get("GITHUB_REPOSITORY")):
        raise RuntimeError("Missing or mismatched trusted GitHub repository")
    run_id = int(raw)
    run = json.loads(gh_api(f"repos/{repo}/actions/runs/{run_id}"))
    if (run.get("id") != run_id or run.get("name") != WORKFLOW
            or run.get("event") != "pull_request"
            or run.get("status") != "completed"
            or run.get("conclusion") != "failure"
            or run.get("run_attempt") != 1):
        raise RuntimeError("Not a first-attempt failed M274 PR workflow")
    head = run.get("head_branch", "")
    if (not isinstance(head, str)
            or not re.fullmatch(r"[\\w./-]+", head)
            or ".." in head or len(head) >= 220):
        raise RuntimeError("Invalid source branch")
    if (run.get("head_repository") or {}).get("full_name") != repo:
        raise RuntimeError("Foreign fork cannot receive a privileged retry")
    # The current exact PR branch HEAD must still equal the reviewed failed run.
    from urllib.parse import quote
    ref = json.loads(gh_api(
        f"repos/{repo}/git/ref/heads/{quote(head, safe='/')}"))
    current_sha = (ref.get("object") or {}).get("sha", "")
    if current_sha != run.get("head_sha"):
        raise RuntimeError("Refusing obsolete M274 SHA")
    response = json.loads(gh_api(
        f"repos/{repo}/actions/runs/{run_id}/jobs?filter=latest&per_page=100"))
    jobs = response.get("jobs") or []
    if response.get("total_count", 101) > 100:
        raise RuntimeError("Refusing unverified paginated M274 jobs")
    failed = [job for job in jobs if job.get("conclusion") == "failure"]
    if len(failed) != 1 or failed[0].get("name") != JOB:
        raise RuntimeError("Not exactly one failed M274 Android emulator job")
    job_id = failed[0].get("id")
    if not isinstance(job_id, int) or job_id <= 0:
        raise RuntimeError("Invalid failed M274 job ID")
    log = gh_api(f"repos/{repo}/actions/jobs/{job_id}/logs")
    if len(log.encode("utf-8")) > MAX_LOG_BYTES:
        raise RuntimeError("Log too large to verify a safe retry")
    selected, reason = candidate(
        {"repository": event["repository"], "workflow_run": run},
        jobs, log, current_sha)
    print(f"M410: {reason}")
    if selected is None:
        print("M410 NO RETRY: actual test failure, stale job or unproven outage")
        return 0
    # Re-run only a verified infrastructure-failed Android job at same SHA.
    gh_api(f"repos/{repo}/actions/jobs/{selected}/rerun", post=True)
    print(f"M410 RETRY: job {selected}, source run {run_id}, maximum attempt 2")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, OSError, subprocess.CalledProcessError, RuntimeError) as exc:
        print(f"M410 BLOCKED: cannot certify or retry safely: {exc}", file=sys.stderr)
        raise SystemExit(1)
