#!/usr/bin/env python3
"""M412: execute scoped PR jobs only for files in the latest push.

Never infer safety from the entire historical PR diff. For synchronize events,
compare the webhook's exact before..after SHAs, verifying ancestry first.
If any context, git data, or glob rule is uncertain, RUN the test.
"""
from __future__ import annotations

import argparse
import fnmatch
import json
import re
import subprocess
import sys
from pathlib import Path

SHA = re.compile(r"^[0-9a-f]{40}$")
GATE_FILES = (
    "scripts/qa/m412_pr_changed_impact.py",
    "test/qa/m412_incremental_pr_impact_test.py",
)


def workflow_paths(source: str) -> list[str]:
    lines = source.splitlines()
    try:
        start = lines.index("  pull_request:")
    except ValueError:
        return []
    paths = []
    inside = False
    for line in lines[start + 1:]:
        if line and not line.startswith(" "):
            break
        if line.startswith("  ") and not line.startswith("    "):
            break
        if line == "    paths:":
            inside = True
            continue
        if inside and line.startswith("    ") and not line.startswith("      "):
            break
        if inside and line.startswith("      - "):
            entry = line[8:].strip()
            if entry and entry[0] in ('"', "'") and entry[-1] == entry[0]:
                entry = entry[1:-1]
            if entry:
                paths.append(entry)
    return paths


def relevant(changed: list[str], patterns: list[str]) -> bool:
    # Negation is deliberately ignored: running extra checks is safe;
    # incorrectly skipping one is not.
    positives = [p for p in patterns if not p.startswith("!")]
    if not positives:
        return True
    for path in changed:
        if path in GATE_FILES:
            return True
        for pattern in positives:
            if fnmatch.fnmatchcase(path, pattern):
                return True
    return False


def decide(event: dict, patterns: list[str],
           before: str, after: str, changed: list[str] | None,
           ancestry_ok: bool) -> tuple[bool, str]:
    if event.get("action") != "synchronize":
        return True, "new/reopened PR: full scope"
    if not (SHA.fullmatch(before) and SHA.fullmatch(after)):
        return True, "missing exact before/after: fail open"
    current = (event.get("pull_request") or {}).get("head", {}).get("sha")
    if current != after:
        return True, "event head differs from after: fail open"
    if before == after or not ancestry_ok or changed is None or not changed:
        return True, "missing or non-fast-forward git diff: fail open"
    if not patterns:
        return True, "no confirmed scoped paths: fail open"
    if relevant(changed, patterns):
        return True, "new files impact this workflow"
    return False, "new files do not impact this workflow; skip expensive jobs"


def git(*args: str) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(["git", *args], capture_output=True, check=False)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workflow", required=True)
    args = parser.parse_args()
    import os
    output = os.environ["GITHUB_OUTPUT"]
    run, reason = True, "safe fallback"
    try:
        event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text())
        paths = workflow_paths(Path(args.workflow).read_text(encoding="utf-8"))
        before, after = str(event.get("before") or ""), str(event.get("after") or "")
        ancestry_ok = False
        changed = None
        if (event.get("action") == "synchronize"
                and SHA.fullmatch(before) and SHA.fullmatch(after)):
            check = git("merge-base", "--is-ancestor", before, after)
            ancestry_ok = check.returncode == 0
            if ancestry_ok:
                diff = git("diff", "--name-only", "-z", before, after)
                if diff.returncode == 0:
                    changed = [s for s in diff.stdout.decode("utf-8").split("\0") if s]
        run, reason = decide(event, paths, before, after, changed, ancestry_ok)
    except (OSError, UnicodeError, ValueError, TypeError, KeyError) as exc:
        run, reason = True, f"uncertain impact ({type(exc).__name__}): fail open"
    with open(output, "a", encoding="utf-8") as f:
        f.write(f"run={'true' if run else 'false'}\n")
    print(f"M412: {'RUN' if run else 'SKIP HEAVY JOB'}: {reason}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
