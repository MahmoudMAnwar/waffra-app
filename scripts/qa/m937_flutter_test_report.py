#!/usr/bin/env python3
"""M937: fail-closed Dart JSON test result summary; no private error log upload."""
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import re

SHA = re.compile(r"[0-9a-f]{40}\Z")
SUITE = re.compile(r"test/[A-Za-z0-9_./-]+\.dart\Z")


def summary(stream, sha):
    if not SHA.fullmatch(sha):
        raise ValueError("Exact SHA required")
    suites, tests, issues = {}, {}, set()
    began, ended = False, None
    for line in stream:
        if not line.strip():
            continue
        try:
            item = json.loads(line)
        except (json.JSONDecodeError, UnicodeError):
            issues.add("malformed_json")
            continue
        if not isinstance(item, dict) or not isinstance(item.get("type"), str):
            issues.add("invalid_event")
            continue
        kind = item["type"]
        if ended is not None:
            issues.add("events_after_end")
            continue
        if kind == "start":
            began = True
        elif kind == "suite":
            obj = item.get("suite", {})
            if not isinstance(obj, dict) or type(obj.get("id")) is not int:
                issues.add("invalid_suite")
                continue
            path = obj.get("path")
            suites[obj["id"]] = (path if isinstance(path, str) and ".." not in path
                                  and SUITE.fullmatch(path) else "unavailable")
        elif kind == "testStart":
            t = item.get("test")
            if (not isinstance(t, dict) or type(t.get("id")) is not int or
                    type(t.get("suiteID")) is not int or
                    not isinstance(t.get("name"), str) or t["id"] in tests):
                issues.add("invalid_or_duplicate_test")
                continue
            tests[t["id"]] = {"suite": t["suiteID"], "name": t["name"][:160],
                              "result": None, "hidden": False, "error": None}
        elif kind == "error":
            ident = item.get("testID")
            if type(ident) is not int or ident not in tests:
                issues.add("unattributed_error")
                continue
            first = str(item.get("error") or "unknown").splitlines()[0][:1024]
            normalized = re.sub(r"\b\d+(?:\.\d+)?\b", "#", first)
            normalized = re.sub(r"[0-9a-fA-F]{16,}", "#", normalized)
            tests[ident]["error"] = hashlib.sha256(
                normalized.encode("utf-8")).hexdigest()[:12]
        elif kind == "testDone":
            ident, result = item.get("testID"), item.get("result")
            if (type(ident) is not int or ident not in tests or
                    tests[ident]["result"] is not None or
                    result not in ("success", "failure", "error") or
                    type(item.get("skipped", False)) is not bool or
                    type(item.get("hidden", False)) is not bool):
                issues.add("invalid_or_duplicate_completion")
                continue
            tests[ident]["result"] = ("skipped" if item.get("skipped", False)
                                      else "passed" if result == "success"
                                      else "failed")
            tests[ident]["hidden"] = item.get("hidden", False)
        elif kind == "done":
            ended = item.get("success")
            if type(ended) is not bool:
                issues.add("invalid_final_verdict")
                ended = False
    if not began or ended is None or not tests:
        issues.add("missing_runner_events")
    if any(t["result"] is None for t in tests.values()):
        issues.add("unfinished_test")
    counts = {"passed": 0, "failed": 0, "skipped": 0}
    groups = defaultdict(lambda: {"tests": [], "files": set()})
    for test in tests.values():
        state = "failed" if test["error"] else test["result"]
        if state is None or (test["hidden"] and state == "passed"):
            continue
        counts[state] += 1
        if state == "failed":
            path = suites.get(test["suite"], "unavailable")
            fp = test["error"] or "unknown-" + hashlib.sha256(
                (path + test["name"]).encode()).hexdigest()[:12]
            groups[fp]["tests"].append({"name": test["name"], "path": path})
            groups[fp]["files"].add(path)
    if not sum(counts.values()):
        issues.add("no_visible_tests")
    if ended and counts["failed"]:
        issues.add("runner_verdict_mismatch")
    if ended is False and not counts["failed"]:
        issues.add("runner_failed_without_test_failure")
    result = {
        "milestone": "M937", "exact_sha": sha, **counts,
        "total": sum(counts.values()), "complete": not issues,
        "runner_success": ended, "issues": sorted(issues),
        "failure_group_estimate": len(groups),
        "failure_groups_not_confirmed_defects": [
            {"fingerprint": key, "affected_tests": len(value["tests"]),
             "files": sorted(value["files"]), "tests": value["tests"]}
            for key, value in sorted(groups.items())
        ],
        "physical_android_verified": False,
        "production_release_approved": False,
    }
    result["passed_gate"] = (not issues and ended is True and
                             counts["failed"] == 0)
    return result


def markdown(r):
    status = "PASS" if r["passed_gate"] else "FAIL / INCOMPLETE"
    lines = [
        "## M937 exact-SHA Flutter test summary", "",
        "Source SHA: " + r["exact_sha"],
        "Result: " + status + " (host tests, NOT Android release approval)",
        "", "| Passed | Failed | Skipped | Total | Approx. failure groups |",
        "|---:|---:|---:|---:|---:|",
        "| {passed} | {failed} | {skipped} | {total} | "
        "{failure_group_estimate} |".format(**r), "",
        "Skipped tests never count as passed. Grouping is approximate, "
        "not a count of confirmed unique defects.",
    ]
    for group in r["failure_groups_not_confirmed_defects"]:
        lines += ["", "Fingerprint " + group["fingerprint"] + " / tests: " +
                  str(group["affected_tests"])]
        lines += ["- " + file for file in group["files"]]
    if r["issues"]:
        lines += ["", "Reporter issues: " + ", ".join(r["issues"])]
    return "\n".join(lines) + "\n"


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--source-sha", required=True)
    p.add_argument("--input", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--markdown", type=Path, required=True)
    args = p.parse_args()
    if not SHA.fullmatch(args.source_sha):
        print("BLOCKED M937: invalid exact SHA")
        return 1
    try:
        with args.input.open(encoding="utf-8") as input_file:
            result = summary(input_file, args.source_sha)
    except (OSError, UnicodeError, ValueError):
        result = summary([], args.source_sha)
        result["issues"] = ["missing_or_invalid_json_file"]
        result["complete"] = result["passed_gate"] = False
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.markdown.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False) +
                           "\n", encoding="utf-8")
    args.markdown.write_text(markdown(result), encoding="utf-8")
    print("M937 " + ("PASS" if result["passed_gate"] else "BLOCKED") +
          " pass=" + str(result["passed"]) +
          " fail=" + str(result["failed"]) +
          " skipped=" + str(result["skipped"]) +
          " estimated_groups=" + str(result["failure_group_estimate"]))
    return 0 if result["passed_gate"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
