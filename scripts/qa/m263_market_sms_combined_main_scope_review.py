#!/usr/bin/env python3
"""M263: PINNED MAIN combined oil feed and SMS notes UI, no finance cutover.

Only the owner-approved M261 + M262 code paths may be promoted to main,
with a single same-source CI review. This report never authorizes stores,
encrypted production migration or real-device attestations.
"""
import json
import os
import subprocess
from pathlib import Path

BASE = "524b03c98535637b5640eaba87d0a2f85048f6ff"
APPROVED = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/release/WAFFRA_APPROVED_CHANGES.txt",
    "lib/main.dart",
    "lib/waffra_oil_market_data.dart",
    "lib/waffra_oil_market_section.dart",
    "scripts/qa/m261_keyless_eia_scope_review.py",
    "scripts/qa/m262_notes_original_sms_scope_review.py",
    "scripts/qa/m263_market_sms_combined_main_scope_review.py",
    "test/m259_oil_quotes_test.dart",
    "test/m227_gold_currency_original_sms_home_test.dart",
    "test/m262_bank_sms_notes_separation_test.dart",
    "test/waffra_m206_day_theme_tour_sms_regression_test.dart",
}

def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()

def require(value, reason):
    if not value:
        raise SystemExit("M263 COMBINED MERGE BLOCKED: " + reason)

def read(path):
    return Path(path).read_text(encoding="utf-8")

def main():
    head = git("rev-parse", "HEAD")
    current_main = git("rev-parse", "refs/remotes/origin/main")
    require(os.environ.get("REVIEW_HEAD_SHA") == head, "commit SHA moved")
    require(current_main == BASE, "main moved; rebuild combined commit")
    require(git("merge-base", current_main, head) == current_main,
            "not based on verified main")
    changed = set(filter(None, git("diff", "--name-only", current_main, head).splitlines()))
    require(changed == APPROVED,
            "changed files differ: " + repr(sorted(changed.symmetric_difference(APPROVED))))
    require(not any(p.startswith(("android/", "firebase/", "lib/storage/"))
                    for p in changed), "sensitive storage/native change")
    oil = read("lib/waffra_oil_market_data.dart")
    require(all(x in oil for x in (
        "parseEiaDailyHtml(", "_fetchPublicSources(api)",
        "RBRTEd.htm", "RWTCd.htm", "RNGWHHDD.htm",
        "fred.stlouisfed.org", "api.eia.gov", "Dollars per Million Btu",
        "quote.isOld(DateTime.now())",
    )), "verified official Brent, WTI, gas fallback missing")
    require(not any(x in oil for x in ("SharedPreferences", "Firestore")),
            "commodity quotes must not access finance/user data")
    ui = read("lib/main.dart")
    a = ui.find("Future<void> transactionDetails(MoneyEntry entry)")
    b = ui.find("\n Widget tile(", a)
    require(a >= 0 and b > a, "transaction details route missing")
    method = ui[a:b]
    require("if(entry.sourceType=='sms'){" in method
            and "readProtectedOriginalSms(entry.id)" in method
            and "protectedOriginalSms:originalBankSms" in method
            and "entry.notes.isEmpty" not in method,
            "edited notes incorrectly block verified vault read")
    require("Key('waffra-transaction-personal-notes')" in ui
            and "Key('waffra-transaction-protected-bank-sms')" in ui,
            "the separate notes and original SMS fields disappeared")
    require("notes:sms?message.text:notes.text" in ui
            and "if(sms)notes.text=text;" not in ui,
            "confirmed SMS original staging accidentally mixed with notes")
    authority = read("lib/storage/waffra_verified_finance_authority.dart")
    require("Map<String, Object?>.unmodifiable({...record, 'notes': ''})" in authority
            and "protectedNotesBeforeLegacyCommit:" in authority,
            "original SMS plaintext legacy redaction removed")
    tests = read("test/m262_bank_sms_notes_separation_test.dart")
    require("edited personal notes never hide the original encrypted SMS" in tests
            and "vault failure is explicit and does not display fake SMS" in tests,
            "independent note and verified original tests absent")
    notes = read("docs/release/WAFFRA_APPROVED_CHANGES.txt")
    require(all(x in notes for x in ("[M261]", "[M262]", "[M263]")),
            "consolidated owner release notes missing")
    report = Path("build/m147-final-review-report.json")
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps({
        "milestone": "M263", "source_sha": head, "approved_main_base": BASE,
        "changed_files": sorted(changed),
        "approved_scope": "READ_ONLY_PUBLIC_MARKET_AND_ENCRYPTED_SMS_DETAIL_UI",
        "production_sqlcipher_cutover": "NO_GO",
        "signed_release": "NOT_APPROVED_BY_SCOPE_ALONE",
        "physical_phones": "NOT_ATTESTED",
    }, indent=2) + "\n", encoding="utf-8")
    print("M263 PASS: exact combined oil and encrypted SMS user-note isolation", head)

if __name__ == "__main__":
    main()
