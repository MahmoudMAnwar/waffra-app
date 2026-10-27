#!/usr/bin/env python3
"""Verify M276 measurement integrity, NOT absolute speed or production readiness."""
import json
import os
from pathlib import Path

path = Path("build/performance/m276_finance_microbench.json")
report = json.loads(path.read_text(encoding="utf-8"))
expected = {
    "sms_split_parse_hash_1",
    "sms_split_parse_hash_20",
    "sms_split_parse_hash_100",
    "sms_preview_1",
    "sms_preview_20",
    "sms_preview_100",
    "ledger_1000_json_round_trip",
    "category_2000_aggregation",
}
assert report["milestone"] == "M276"
assert report["environment"] == "flutter_test_host_not_physical_android"
assert report["decision"] == "informational_only_no_fixed_latency_gate"
assert report["samples_per_scenario"] == 21
scenarios = report["scenarios"]
assert len(scenarios) == len(expected)
assert {s["name"] for s in scenarios} == expected
for item in scenarios:
    assert item["samples"] == 21
    assert 0 <= item["min_us"] <= item["p50_us"] <= item["p95_us"] <= item["max_us"]
sha = os.getenv("GITHUB_SHA")
if sha:
    assert report["head_sha"] == sha, "wrong SHA performance result"
print("M276: 8 verified synthetic performance measurements from exact HEAD.")
print("Numbers are informational; do not use CI host timing as Android FPS.")
