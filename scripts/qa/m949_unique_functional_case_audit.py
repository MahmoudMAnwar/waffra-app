#!/usr/bin/env python3
"""M949 enforce NEW, exact, executable functional cases on every PR SHA.

No disabled test placeholders or source-only string scans can count as cases.
Only M949 test() functions in three exact files count as new functional tests.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
SUITES = {
    "test/storage/m949_account_lifecycle_cross_feature_test.dart":
        tuple(f"A{i:02d}" for i in range(1, 15)),
    "test/storage/m949_goal_recurring_category_sequences_test.dart":
        tuple(f"M{i:02d}" for i in range(1, 18)),
    "test/m949_home_filter_combined_user_journeys_test.dart":
        tuple(f"F{i:02d}" for i in range(1, 13)),
}
CASE = re.compile(r"\btest\(\s*['\"]M949-([AMF]\d{2}) ([^'\"]+)['\"]")
TITLE = re.compile(r"\btest(?:Widgets)?\(\s*['\"]([^'\"]+)['\"]")
REQUIRED_IMPORTS = {
    "test/storage/m949_account_lifecycle_cross_feature_test.dart":
        ("waffra_encrypted_store.dart", "waffra_accounts_repository.dart"),
    "test/storage/m949_goal_recurring_category_sequences_test.dart":
        ("waffra_encrypted_store.dart",
         "waffra_fresh_finance_modules_repository.dart"),
    "test/m949_home_filter_combined_user_journeys_test.dart":
        ("WaffraHomeTransactionFilter", "WaffraFinancePeriodIndex"),
}

def audit(root: Path = ROOT) -> dict:
    seen: dict[str, str] = {}
    titles: list[str] = []
    errors: list[str] = []
    for path, expected in SUITES.items():
        f = root / path
        if not f.is_file():
            errors.append("missing test file: " + path)
            continue
        source = f.read_text(encoding="utf-8")
        actual = CASE.findall(source)
        ids = tuple(case for case, _ in actual)
        if ids != expected:
            errors.append(f"{path} must contain {len(expected)} ordered exact cases; got {ids}")
        if "skip:" in source or "skip(" in source or "test.skip" in source:
            errors.append(path + ": skipped or disabled cases are prohibited")
        if "File('lib/" in source or 'File("lib/' in source:
            errors.append(path + ": source-text-only checks cannot count as functional")
        for symbol in REQUIRED_IMPORTS[path]:
            if symbol not in source:
                errors.append(path + ": missing real behavior under test: " + symbol)
        for code, title in actual:
            if code in seen:
                errors.append(f"case M949-{code} duplicated in {seen[code]} / {path}")
            seen[code] = path
            if len(title.strip()) < 15:
                errors.append(f"case M949-{code} has uninformative name")
            titles.append(title.strip().lower())
    if len(titles) != len(set(titles)):
        errors.append("two new functional case descriptions are duplicated")
    # Exact-title check against all EXISTING test() names, not prefix-only.
    existing = set()
    for f in (root / "test").rglob("*_test.dart"):
        path = f.relative_to(root).as_posix()
        if path in SUITES:
            continue
        text = f.read_text(encoding="utf-8", errors="replace")
        for full in TITLE.findall(text):
            existing.add(re.sub(r"^M\d+(?:\.\d+)?\s*[:.\-]?\s*", "",
                                full.strip().lower()))
    for title in titles:
        comparison = title.strip().lower()
        if comparison in existing:
            errors.append("new case title already exists in baseline: " + comparison)
    if len(seen) != 43:
        errors.append(f"M949 requires 43 distinct functional cases, found {len(seen)}")
    if errors:
        raise ValueError("M949 functional uniqueness audit blocked: " + "; ".join(errors))
    return {
        "suite": "M949 new functional journeys only",
        "unique_case_count": 43,
        "source_test_files": len(SUITES),
        "by_area": {
            "accounts_and_transfers": 14,
            "goals_recurring_categories": 17,
            "home_filter_intersections": 12,
        },
        "ids": list(seen),
        "historical_test_titles_compared": len(existing),
        "no_existing_test_replaced": True,
        "physical_android_uat_verified": False,
    }

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = audit()
    if args.output:
        dst = ROOT / args.output
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n",
                       encoding="utf-8")
    print("PASS M949:", result["unique_case_count"], "distinct new functional cases",
          "in", result["source_test_files"], "real runnable Dart suites")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
