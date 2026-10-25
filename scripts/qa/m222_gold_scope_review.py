#!/usr/bin/env python3
"""M222 exact-head gold feature and release-note freshness scope review.

No production cutover, signed release authorization or hardware QA implied.
"""
import json
import os
from pathlib import Path
import subprocess

BASE = "e9eab885f7830973d7d0c08449d0868faa71ece4"
FILES = {
    "lib/waffra_gold_calculator.dart",
    "lib/currency_converter.dart",
    "test/m222_gold_calculator_test.dart",
    "docs/release/WAFFRA_APPROVED_CHANGES.txt",
    ".github/workflows/m147-final-main-review-gate.yml",
    "scripts/qa/m222_gold_scope_review.py",
}

def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()

def must(condition, reason):
    if not condition:
        raise SystemExit("M222 REVIEW BLOCKED: " + reason)

head = git("rev-parse", "HEAD")
must(head == os.environ.get("REVIEW_HEAD_SHA", ""), "wrong PR SHA checked out")
must(git("rev-parse", "refs/remotes/origin/main") == BASE,
     "main advanced; rebase and re-review before merging")
must(git("merge-base", BASE, head) == BASE, "candidate not based on certified main")
changes = set(git("diff", "--name-only", BASE, head).splitlines())
must(changes == FILES,
     "unexpected file scope: " + repr(sorted(changes ^ FILES)))
gold = Path("lib/waffra_gold_calculator.dart").read_text()
converter = Path("lib/currency_converter.dart").read_text()
notes = Path("docs/release/WAFFRA_APPROVED_CHANGES.txt").read_text()
test = Path("test/m222_gold_calculator_test.dart").read_text()
must(all(t in gold for t in (
    "troyOunceGrams = 31.1034768", "https://api.gold-api.com/price/XAU",
    "https://open.er-api.com/v6/latest/USD", "rate('SAR')",
    "rate(currency)", "supportedKarats", "throw const FormatException",
    "أسعار الذهب",
)), "missing critical gold/FX contract")
must("WaffraGoldCalculatorPage(" in converter, "gold not linked to currency tool")
must("M222" in notes and "أسعار الذهب" in notes, "release notes out of date")
must("MockClient" in test and "EGP" in test and "throwsFormatException" in test,
     "insufficient currency and fail-closed tests")
# The release notes must include EVERY production code change through the
# reviewed head; they must NOT be predated by the gold/converter changes.
last_notes = git("log", "-1", "--format=%H", "--", "docs/release/WAFFRA_APPROVED_CHANGES.txt")
for changed in ("lib/currency_converter.dart", "lib/waffra_gold_calculator.dart"):
    code_head = git("log", "-1", "--format=%H", "--", changed)
    must(subprocess.run(["git", "merge-base", "--is-ancestor", code_head, last_notes]).returncode == 0,
         "release notes older than " + changed)
report = {
    "milestone": "M222", "head": head, "base": BASE,
    "changed_files": sorted(changes), "same_head_review_passed": True,
    "release_allowed": False, "production_sqlcipher_cutover": False,
    "physical_android_evidence": False,
}
out = Path("build/m147-final-review-report.json")
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
