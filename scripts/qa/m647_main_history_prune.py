#!/usr/bin/env python3
"""M647: bounded, irreversible cleanup of OLD failed/skipped/cancelled MAIN Actions runs.

Never accepts untrusted PR events, never deletes success or artifact-bearing runs.
New source is trusted only once merged to main; manual mode defaults to DRY RUN.
"""
from __future__ import annotations

import datetime as dt
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

REPOSITORY = "MahmoudMAnwar/waffra-app"
CONCLUSIONS = ("skipped", "failure", "cancelled")
MAIN_EVENTS = frozenset(("push", "workflow_run", "schedule", "workflow_dispatch"))
AGE = dt.timedelta(hours=48)
MAX_DELETE = 250
MAX_PAGES = 12
PER_PAGE = 100
CONFIRM = "DELETE_OLD_MAIN_ACTIONS_HISTORY"
SHA = re.compile(r"[0-9a-f]{40}\Z")


def utc(value):
    if not isinstance(value, str) or not value:
        return None
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    return parsed if parsed.tzinfo is not None else None


def eligible(run, *, now, main_sha, current_run_id, repository=REPOSITORY):
    """Fail closed on any missing, unknown, newer or non-main metadata."""
    if not isinstance(run, dict):
        return False
    if run.get("status") != "completed" or run.get("conclusion") not in CONCLUSIONS:
        return False
    if run.get("head_branch") != "main" or run.get("event") not in MAIN_EVENTS:
        return False
    if (run.get("head_repository") or {}).get("full_name") != repository:
        return False
    if run.get("pull_requests"):
        return False
    head = run.get("head_sha")
    if not isinstance(head, str) or not SHA.fullmatch(head) or head == main_sha:
        return False
    rid = run.get("id")
    if not isinstance(rid, int) or isinstance(rid, bool) or rid < 1 or rid == current_run_id:
        return False
    born, ended = utc(run.get("created_at")), utc(run.get("updated_at"))
    if born is None or ended is None:
        return False
    cutoff = now - AGE
    return born <= ended <= cutoff and born <= cutoff


def approve_execution(env, event):
    """Only trusted main push/schedule, or explicitly confirmed manual dispatch."""
    if (env.get("GITHUB_REPOSITORY") != REPOSITORY or
            env.get("GITHUB_REF") != "refs/heads/main"):
        raise RuntimeError("M647 refuses anything other than trusted Waffra main")
    name = env.get("GITHUB_EVENT_NAME")
    if name not in ("push", "schedule", "workflow_dispatch"):
        raise RuntimeError("M647 never executes cleanup from pull_request or workflow_run")
    sha = env.get("GITHUB_SHA", "")
    if not SHA.fullmatch(sha):
        raise RuntimeError("M647 requires an exact main SHA")
    if name != "workflow_dispatch":
        return False
    inputs = event.get("inputs") or {}
    dry = str(inputs.get("dry_run", "true")).lower() != "false"
    if not dry and inputs.get("confirm_delete") != CONFIRM:
        raise RuntimeError("M647 manual deletion needs exact typed confirmation")
    return dry


def github_api(method, route, token):
    if method not in ("GET", "DELETE") or not route.startswith("/repos/" + REPOSITORY + "/"):
        raise RuntimeError("M647 unsafe GitHub API request refused")
    if not token:
        raise RuntimeError("Missing privileged GitHub Actions maintenance token")
    req = urllib.request.Request(
        "https://api.github.com" + route, method=method,
        headers={"Authorization": "Bearer " + token,
                 "Accept": "application/vnd.github+json",
                 "X-GitHub-Api-Version": "2022-11-28",
                 "User-Agent": "Waffra-M647-main-history-prune"},
    )
    with urllib.request.urlopen(req, timeout=45) as response:
        raw = response.read()
    return json.loads(raw) if raw else {}


class MainPruner:
    def __init__(self, api, *, now, run_id, commit_sha, sleep=time.sleep):
        self.api, self.now, self.run_id, self.commit_sha, self.sleep = (
            api, now, run_id, commit_sha, sleep)

    def check_main(self):
        response = self.api("GET", "/repos/" + REPOSITORY + "/branches/main")
        sha = (response.get("commit") or {}).get("sha")
        if sha != self.commit_sha or not SHA.fullmatch(sha or ""):
            raise RuntimeError("M647 main moved or checkout does not match live default branch")
        return sha

    def snapshot(self):
        """Collect immutable IDs BEFORE issuing DELETE (pagination cannot shift)."""
        found = {}
        until = (self.now - AGE).date().isoformat()
        for conclusion in CONCLUSIONS:
            for page in range(1, MAX_PAGES + 1):
                qs = urllib.parse.urlencode({
                    "branch": "main", "status": conclusion,
                    "created": ".." + until,
                    "per_page": PER_PAGE, "page": page,
                })
                data = self.api("GET", "/repos/" + REPOSITORY + "/actions/runs?" + qs)
                rows = data.get("workflow_runs")
                if not isinstance(rows, list):
                    raise RuntimeError("Missing GitHub Actions run list; refuse deletion")
                for run in rows:
                    if (eligible(run, now=self.now, main_sha=self.commit_sha,
                                 current_run_id=self.run_id) and
                            run.get("conclusion") == conclusion):
                        found[run["id"]] = run
                if len(rows) < PER_PAGE:
                    break
        # Process oldest first, never mutate the list while paginating.
        return sorted(found.values(), key=lambda run: (run["created_at"], run["id"]))

    def execute(self, *, dry_run):
        self.check_main()
        runs = self.snapshot()
        counts = {s: 0 for s in CONCLUSIONS}
        summary = {"snapshotted": len(runs), "reviewed": 0, "with_artifacts": 0,
                   "stale_or_protected": 0, "previewed": 0, "deleted": 0,
                   "by_conclusion": counts, "example_ids": []}
        for candidate in runs:
            if summary["deleted"] + summary["previewed"] >= MAX_DELETE:
                break
            # Check live main again every 25 reviewed candidates.
            if summary["reviewed"] % 25 == 0:
                self.check_main()
            summary["reviewed"] += 1
            rid = candidate["id"]
            live = self.api("GET", "/repos/" + REPOSITORY + "/actions/runs/" + str(rid))
            if (not eligible(live, now=self.now, main_sha=self.commit_sha,
                             current_run_id=self.run_id) or
                    live.get("head_sha") != candidate.get("head_sha") or
                    live.get("conclusion") != candidate.get("conclusion")):
                summary["stale_or_protected"] += 1
                continue
            artifacts = self.api(
                "GET", "/repos/" + REPOSITORY + "/actions/runs/"
                + str(rid) + "/artifacts?per_page=1")
            if not isinstance(artifacts.get("total_count"), int):
                raise RuntimeError("Unknown artifact status: must preserve historical run")
            if artifacts["total_count"] != 0:
                summary["with_artifacts"] += 1
                continue
            if not dry_run:
                self.check_main()
                self.api("DELETE", "/repos/" + REPOSITORY + "/actions/runs/" + str(rid))
                self.sleep(0.6)
                summary["deleted"] += 1
                print("M647 DELETED", rid, candidate["conclusion"], candidate.get("name"), flush=True)
            else:
                summary["previewed"] += 1
                print("M647 DRY RUN", rid, candidate["conclusion"], candidate.get("name"), flush=True)
            counts[candidate["conclusion"]] += 1
            if len(summary["example_ids"]) < 12:
                summary["example_ids"].append(rid)
        return summary


def write_summary(summary, dry_run, path):
    text = (
        "## M647 main historical Actions records — "
        + ("DRY RUN" if dry_run else "DELETED") + "\n"
        + "Only completed main failure/skipped/cancelled older than 48h, "
        + "with zero artifacts; latest main SHA, successes, active jobs and PRs protected.\n\n"
        + "| Field | Count |\n|---|---:|\n"
        + "".join("| " + label + " | " + str(value) + " |\n"
                  for label, value in summary.items() if label != "by_conclusion"
                  and label != "example_ids")
        + "".join("| " + ("preview" if dry_run else "deleted") + " " + key + " | "
                  + str(value) + " |\n"
                  for key, value in summary["by_conclusion"].items())
        + "\nExample run IDs: " + ", ".join(map(str, summary["example_ids"])) + "\n"
        + "\nDeletion of a completed GitHub Actions run removes its logs and cannot be undone.\n"
    )
    if path:
        with open(path, "a", encoding="utf-8") as out:
            out.write(text + "\n")
    print("M647 SUMMARY", json.dumps(summary, sort_keys=True), flush=True)


def main():
    event_path = os.environ.get("GITHUB_EVENT_PATH")
    if not event_path:
        raise RuntimeError("M647 missing authenticated GitHub event")
    event = json.loads(Path(event_path).read_text(encoding="utf-8"))
    dry = approve_execution(os.environ, event)
    token = os.environ.get("GH_TOKEN")
    api = lambda method, route: github_api(method, route, token)
    now = dt.datetime.now(dt.timezone.utc)
    pruner = MainPruner(
        api, now=now, run_id=int(os.environ["GITHUB_RUN_ID"]),
        commit_sha=os.environ["GITHUB_SHA"])
    results = pruner.execute(dry_run=dry)
    write_summary(results, dry, os.environ.get("GITHUB_STEP_SUMMARY"))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, RuntimeError, urllib.error.URLError) as exc:
        print("M647 BLOCKED:", exc, file=sys.stderr)
        sys.exit(1)
