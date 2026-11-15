#!/usr/bin/env python3
"""M950 new functional coverage identity and old-suite no-duplicate guard.

Counts ONLY actual test() cases, not loop input examples or source greps.
All M950 tests exercise imported business policy or disposable SQLCipher.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
SUITES = {
  "test/m950_account_sms_due_budget_decision_matrix_test.dart":
    tuple(f"P{i:02d}" for i in range(1,29)),
  "test/storage/m950_verified_monthly_scopes_and_history_test.dart":
    tuple(f"S{i:02d}" for i in range(1,19)),
}
CASE = re.compile(r"\btest\(\s*['\"]M950-([PS]\d\d) ([^'\"]+)['\"]")
TITLE = re.compile(r"\btest(?:Widgets)?\(\s*['\"]([^'\"]+)['\"]")

def audit(root: Path=ROOT) -> dict:
    failures=[]
    all_cases={}
    all_titles={}
    for path, expected in SUITES.items():
        source_path=root/path
        if not source_path.is_file():
            failures.append(f"Missing executable suite: {path}")
            continue
        code=source_path.read_text(encoding="utf-8")
        found=CASE.findall(code)
        found_ids=tuple(x for x,_ in found)
        if found_ids!=expected:
            failures.append(f"Exact ordered M950 IDs mismatch in {path}: {found_ids}")
        if "skip:" in code or "test.skip" in code or "skip(" in code:
            failures.append(f"New M950 test skipped or disabled: {path}")
        if "File('lib/" in code or 'File("lib/' in code:
            failures.append(f"Source-text-only check is not functional: {path}")
        for case,name in found:
            if case in all_cases:
                failures.append(f"Duplicate M950 case {case}")
            if len(name.strip())<18:
                failures.append(f"Case M950-{case} lacks a useful user-scenario description")
            all_cases[case]=path
            key=name.strip().lower()
            if key in all_titles:
                failures.append(f"Repeated functional behavior title: {name}")
            all_titles[key]=path
    previous=set()
    for f in (root/"test").rglob("*_test.dart"):
        relative=f.relative_to(root).as_posix()
        if relative in SUITES:
            continue
        source=f.read_text(encoding="utf-8", errors="replace")
        previous.update(x.strip().lower() for x in TITLE.findall(source))
    for title in all_titles:
        if title in previous:
            failures.append(f"Already existing test title reused: {title}")
    if len(all_cases)!=46:
        failures.append(f"Expected 46 new M950 functional tests, found {len(all_cases)}")
    if failures:
        raise ValueError("M950 duplicate/disabled functional audit FAILED: "+
                         "; ".join(failures))
    return {
      "new_functional_case_count":46,
      "new_functional_total_with_M949":89,
      "areas":{
        "bank_sms_recurring_budget_goal_policy":28,
        "encrypted_monthly_account_budget_history":18,
      },
      "new_test_files":len(SUITES),
      "all_unique_ids":list(all_cases),
      "prior_test_titles_scanned":len(previous),
      "device_android_verified":False,
    }

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--output",type=Path)
    args=parser.parse_args()
    report=audit()
    print(json.dumps(report,ensure_ascii=False,sort_keys=True))
    if args.output:
        path=ROOT/args.output
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",
                        encoding="utf-8")
