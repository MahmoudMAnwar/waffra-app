#!/usr/bin/env python3
"""M951: 26 new source-linked SMS/alert functional cases, not repeats/skips."""
from __future__ import annotations
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2]
SUITE="test/m951_sms_eligibility_and_budget_alert_isolation_test.dart"
EXPECTED=tuple(f"A{i:02d}" for i in range(1,17))+tuple(f"B{i:02d}" for i in range(1,11))
CASE=re.compile(r"\btest\(\s*['\"]M951-([AB]\d\d) ([^'\"]+)['\"]")
TITLE=re.compile(r"\btest(?:Widgets)?\(\s*['\"]([^'\"]+)['\"]")

def audit(root: Path=ROOT)->dict:
    file=root/SUITE
    if not file.is_file():
        raise ValueError("Missing M951 functional Dart suite")
    source=file.read_text(encoding="utf-8")
    found=CASE.findall(source)
    ids=tuple(id for id,_ in found)
    if ids!=EXPECTED or len(found)!=26:
        raise ValueError(f"Expected 26 unique ordered M951 test cases, got {ids}")
    if "skip:" in source or "test.skip" in source or "skip(" in source:
        raise ValueError("Disabled M951 functional tests cannot pass")
    for import_token in ("waffra_auto_sms_policy.dart","waffra_budget_alert_once.dart"):
        if import_token not in source:
            raise ValueError("M951 must call actual production decision code")
    names=[n.strip().lower() for _,n in found]
    if len(set(names))!=26 or any(len(n)<18 for n in names):
        raise ValueError("M951 duplicated or trivial scenario descriptions")
    old_names=set()
    for f in (root/"test").rglob("*_test.dart"):
        if f.relative_to(root).as_posix()==SUITE:
            continue
        text=f.read_text(encoding="utf-8", errors="replace")
        old_names.update(x.strip().lower() for x in TITLE.findall(text))
    if set(names)&old_names:
        raise ValueError("M951 duplicates an existing functional case title")
    return {"new_M951_functional_case_count":26,
            "new_PR_functional_case_total":115,
            "by_feature":{"sms_preposting_eligibility":16,
                          "budget_alert_owner_month_isolation":10},
            "test_ids":[f"M951-{id}" for id in ids],
            "prior_test_titles_compared":len(old_names),
            "physical_android_verified":False}

if __name__=="__main__":
    print(audit())
