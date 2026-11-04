#!/usr/bin/env python3
"""M262 additive user-notes / encrypted original bank SMS split (NO cutover)."""
import json
import os
import subprocess
from pathlib import Path

BASE_MAIN = "524b03c98535637b5640eaba87d0a2f85048f6ff"
APPROVED = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/release/WAFFRA_APPROVED_CHANGES.txt",
    "lib/main.dart",
    "scripts/qa/m262_notes_original_sms_scope_review.py",
    "test/m227_gold_currency_original_sms_home_test.dart",
    "test/waffra_m206_day_theme_tour_sms_regression_test.dart",
    "test/m262_bank_sms_notes_separation_test.dart",
}

def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()

def require(ok, why):
    if not ok:
        raise SystemExit("M262 BLOCKED: " + why)

def main():
    head = git("rev-parse", "HEAD")
    base = git("rev-parse", "refs/remotes/origin/main")
    require(os.environ.get("REVIEW_HEAD_SHA") == head, "head SHA mismatch")
    require(base == BASE_MAIN, "main advanced; rebase and re-certify")
    require(git("merge-base", base, head) == base, "unexpected ancestry")
    changes = set(filter(None, git("diff", "--name-only", base, head).splitlines()))
    require(changes == APPROVED, "unexpected files: " +
            repr(sorted(changes.symmetric_difference(APPROVED))))
    source = Path("lib/main.dart").read_text(encoding="utf-8")
    start = source.find("Future<void> transactionDetails(MoneyEntry entry)")
    end = source.find("\n Widget tile(", start)
    require(start != -1 and end > start, "detail route unavailable")
    detail = source[start:end]
    require("if(entry.sourceType=='sms'){" in detail and
            "readProtectedOriginalSms(entry.id)" in detail and
            "protectedOriginalSms:originalBankSms" in detail and
            "entry.notes.isEmpty" not in detail,
            "vault read remains coupled to editable notes or is missing")
    require("notes:sms?message.text:notes.text" in source and
            "if(sms)notes.text=text;" not in source,
            "SMS encrypted staging separated from personal notes input")
    require("Key('waffra-transaction-personal-notes')" in source and
            "Key('waffra-transaction-protected-bank-sms')" in source and
            "protectedOriginalSms!" in source,
            "two visible independent transaction detail fields required")
    require("protectedSmsNotes: const WaffraEncryptedSmsNotesVault()" in
            Path("lib/storage/waffra_production_finance_authority_binding.dart").read_text(),
            "original SMS encrypted vault disconnected")
    require("WaffraLegacySmsNotesPrivacyGate.rejectConfirmedSmsNotes(copied)" in
            Path("lib/storage/waffra_home_finance_persistence.dart").read_text(),
            "unencrypted SMS original privacy gate missing")
    require(not any(path.startswith(("lib/storage/", "android/", "firebase/"))
                    for path in changes),
            "finance storage/auth/security implementation changed")
    require("[M262]" in Path("docs/release/WAFFRA_APPROVED_CHANGES.txt").read_text(),
            "release notes missing")
    report = Path("build/m147-final-review-report.json")
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps({
        "milestone": "M262",
        "head": head,
        "base_main": base,
        "changes": sorted(changes),
        "scope": "UI_NOTES_VS_ENCRYPTED_ORIGINAL_SMS_NO_STORAGE_CHANGE",
        "sqlcipher_cutover": "NO_GO",
        "apk_production": "NOT_APPROVED",
    }, indent=2) + "\n", encoding="utf-8")
    print("M262 PASS: original SMS isolation independent of user notes", head)

if __name__ == "__main__":
    main()
