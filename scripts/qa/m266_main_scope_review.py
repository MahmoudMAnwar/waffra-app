#!/usr/bin/env python3
"""M266 exact-main scope audit. Report is NOT SQLCipher release approval."""
import json
import os
import re
import subprocess
from pathlib import Path


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True).strip()


def require(ok: bool, message: str) -> None:
    if not ok:
        raise SystemExit("M266 NO-GO / scope review failed: " + message)


def main() -> None:
    head = git("rev-parse", "HEAD")
    expected = os.environ.get("REVIEW_HEAD_SHA")
    require(expected is not None and head == expected, "reviewed commit changed")
    base = git("rev-parse", "refs/remotes/origin/main")
    require(git("merge-base", head, base) == base,
            "PR not based on current main; rebase and review again")
    changed = set(filter(None, git("diff", "--name-only", base + "...HEAD").splitlines()))
    allowed = {
        "docs/qa/sqlcipher-cutover-readiness-20261027.md",
        "lib/waffra_widget_capture.part.dart",
        "test/storage/m266_widget_source_fail_closed_ui_test.dart",
        ".github/workflows/m266-sqlcipher-precutover-qa.yml",
        ".github/workflows/m147-final-main-review-gate.yml",
        "scripts/qa/m266_main_scope_review.py",
    }
    require(changed == allowed,
            "unexpected or missing files: " + repr(sorted(changed ^ allowed)))
    widget = Path("lib/waffra_widget_capture.part.dart").read_text()
    require("if(widget.testSourceProbe!=null){" in widget
            and "throw StateError('Widget finance source has not been verified.')" in widget
            and "if(!_sourceReady||_saving||_analyzing||_selected.isEmpty)return;" in widget,
            "unverified widget access path")
    require("_financeBinding?.authority??" not in widget,
            "unbound legacy authority fallback still exists")
    release = Path("lib/storage/waffra_production_cutover_release_gate.dart").read_text()
    guard = Path("lib/storage/waffra_production_finance_source_guard.dart").read_text()
    require("bool get automaticallyActivateSqlCipher => false;" in release,
            "automatic SQLCipher activation enabled")
    require("all_live_writers_not_yet_routed" in guard,
            "existing production writer warning removed")
    routing = Path("lib/storage/waffra_production_finance_routing_gate.dart").read_text()
    routes = re.search(r"enum WaffraFinanceRoute\s*\{([^}]+)\}", routing, re.S)
    require(routes is not None, "finance route inventory absent")
    route_names = [v.strip().split("//")[0].strip().rstrip(",")
                   for v in routes.group(1).splitlines()
                   if v.strip() and not v.strip().startswith("//")]
    require(len([v for v in route_names if re.fullmatch(r"[A-Za-z]\w*", v)]) == 24,
            "24-route inventory changed")
    workflow = Path(".github/workflows/m266-sqlcipher-precutover-qa.yml").read_text()
    require("test/storage/m266_widget_source_fail_closed_ui_test.dart" in workflow
            and "run-m202-sqlcipher-binder-android.sh" in workflow,
            "widget or Android QA not scheduled")
    report = {
        "milestone": "M266",
        "reviewed_sha": head,
        "base_main_sha": base,
        "changed_files": sorted(changed),
        "route_inventory": 24,
        "live_device_route_attestations": 0,
        "two_physical_phones_attested": False,
        "production_sqlcipher_activated": False,
        "release_ready": False,
        "review_status": "SCOPED_FIX_AND_QA_ONLY_NO_PRODUCTION_CUTOVER",
    }
    target = Path("build/m147-final-review-report.json")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
