#!/usr/bin/env python3
"""M948: no false green from all-skipped, partial or stale-sha Flutter smoke.

Invoke AFTER M937 creates a per-shard report. Does not rely on workflow color.
Physical Android proof is independent and never conflated with host CI.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import re

SHA = re.compile(r"[0-9a-f]{40}\Z")
GROUPS = frozenset({"money", "experience", "safety"})


def validate(report: dict, *, sha: str, group: str) -> dict:
    if not SHA.fullmatch(sha) or group not in GROUPS:
        raise ValueError("M948 exact commit and recognized smoke shard required")
    if not isinstance(report, dict):
        raise ValueError("M948 missing JSON Flutter evidence")
    if report.get("exact_sha") != sha:
        raise ValueError("M948 stale SHA: test evidence belongs to another commit")
    if report.get("complete") is not True or report.get("runner_success") is not True:
        raise ValueError("M948 incomplete test run cannot be green")
    if report.get("passed_gate") is not True:
        raise ValueError("M948 M937 reporter did not certify success")
    for key in ("passed", "failed", "skipped", "total"):
        if type(report.get(key)) is not int:
            raise ValueError("M948 missing exact test-case counters")
    if report["failed"] != 0 or report["skipped"] != 0:
        raise ValueError("M948 no failing OR skipped tests allowed")
    if report["passed"] < 10 or report["total"] != report["passed"]:
        raise ValueError("M948 incomplete or implausibly empty test shard")
    if report.get("issues") or report.get("failure_group_estimate") != 0:
        raise ValueError("M948 unreliable or grouped-error test evidence")
    if report.get("physical_android_verified") is not False or (
        report.get("production_release_approved") is not False
    ):
        raise ValueError("M948 host tests cannot assert physical release approval")
    return {"group": group, "exact_sha": sha, "passed": report["passed"],
            "failed": 0, "skipped": 0, "host_smoke_passed": True,
            "android_uat_passed": False}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--sha", required=True)
    parser.add_argument("--group", required=True, choices=sorted(GROUPS))
    args = parser.parse_args()
    result = validate(json.loads(args.input.read_text(encoding="utf-8")),
                      sha=args.sha, group=args.group)
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
