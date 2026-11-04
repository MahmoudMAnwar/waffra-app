#!/usr/bin/env python3
"""M261 exact-main keyless official EIA source-only safety check."""
import json
import os
import subprocess
from pathlib import Path

BASE_MAIN = "524b03c98535637b5640eaba87d0a2f85048f6ff"
APPROVED = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/release/WAFFRA_APPROVED_CHANGES.txt",
    "lib/waffra_oil_market_data.dart",
    "lib/waffra_oil_market_section.dart",
    "scripts/qa/m261_keyless_eia_scope_review.py",
    "test/m259_oil_quotes_test.dart",
}

def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()

def require(ok, detail):
    if not ok:
        raise SystemExit("M261 BLOCKED: " + detail)

def read(path):
    return Path(path).read_text(encoding="utf-8")

def main():
    head = git("rev-parse", "HEAD")
    main = git("rev-parse", "refs/remotes/origin/main")
    require(head == os.environ.get("REVIEW_HEAD_SHA"), "unreviewed commit")
    require(main == BASE_MAIN, "main advanced; rebase and rerun checks")
    require(git("merge-base", main, head) == main, "not based on pinned main")
    files = set(filter(None, git("diff", "--name-only", main, head).splitlines()))
    require(files == APPROVED, "unexpected/missing modified files: " +
            repr(sorted(files.symmetric_difference(APPROVED))))
    require(not any(path.startswith(("android/", "firebase/", "lib/storage/"))
                    for path in files), "financial or native storage mutated")
    src = read("lib/waffra_oil_market_data.dart")
    require(all(x in src for x in (
        "/dnav/pet/hist/RBRTEd.htm",
        "/dnav/pet/hist/RWTCd.htm",
        "/dnav/ng/hist/RNGWHHDD.htm",
        "parseEiaDailyHtml(",
        "_fetchEiaPublicPages(",
        "_fetchPublicSources(",
        "fred.stlouisfed.org",
        "api.eia.gov",
        "Dollars per Million Btu",
        "monday.weekday!=DateTime.monday",
        "quote.isOld(DateTime.now())",
    )), "one source or safety validator is missing")
    require(not any(token in src for token in (
        "SharedPreferences", "Firebase", "Firestore", "DataBase")),
        "commodity data must not touch the user finance source")
    tests = read("test/m259_oil_quotes_test.dart")
    require(all(x in tests for x in (
        "keyless source falls back to official EIA pages on FRED 403",
        "partial official EIA response cannot make up a missing oil type",
        "official keyless EIA daily HTML parses dates and rejects wrong units",
        "registered EIA key requests independent crude and gas source routes",
    )), "keyless and authenticated source regression missing")
    require("مليون وحدة حرارية" in read("lib/waffra_oil_market_section.dart"),
            "user-facing gas units disappeared")
    require("[M261]" in read("docs/release/WAFFRA_APPROVED_CHANGES.txt"),
            "release notes not updated")
    report = Path("build/m147-final-review-report.json")
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps({
        "milestone": "M261",
        "source_commit": head,
        "base_main": main,
        "files": sorted(files),
        "approved_scope": "OFFICIAL_PUBLIC_COMMODITY_READ_ONLY",
        "sqlcipher_production": "NO_GO",
        "physical_android_acceptance": "NOT_YET_PERFORMED",
    }, indent=2) + "\n", encoding="utf-8")
    print("M261 PASS: pinned-main commodity-source-only scope", head)

if __name__ == "__main__":
    main()
