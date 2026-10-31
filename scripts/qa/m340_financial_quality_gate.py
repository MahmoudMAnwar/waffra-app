#!/usr/bin/env python3
"""Read-only, exact-source finance safety preflight for the Waffra PR quality gate.

This checks for critical control wiring; it does NOT replace Flutter unit
tests, Android physical-device evidence, or independent financial review.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Mapping

ROOT = Path(__file__).resolve().parents[2]
SOURCE_PATHS = (
    "lib/main.dart",
    "lib/waffra_sms_multicurrency_review.dart",
    "lib/waffra_ai_recorded_answers.dart",
    "lib/waffra_smart_features.dart",
    "lib/waffra_foreign_currency_preview.dart",
    "lib/storage/waffra_verified_finance_authority.dart",
    "lib/storage/waffra_verified_encrypted_finance_bridge.dart",
    "lib/storage/waffra_production_cutover_release_gate.dart",
)


def load_sources(root: Path = ROOT) -> dict[str, str]:
    return {name: (root / name).read_text(encoding="utf-8") for name in SOURCE_PATHS}


def audit_sources(sources: Mapping[str, str]) -> list[str]:
    problems: list[str] = []

    def require(path: str, evidence: str, reason: str) -> None:
        if evidence not in sources.get(path, ""):
            problems.append(f"{path}: {reason}")

    main = "lib/main.dart"
    curr = "lib/waffra_sms_multicurrency_review.dart"
    ai = "lib/waffra_smart_features.dart"
    model = "lib/waffra_ai_recorded_answers.dart"
    fx = "lib/waffra_foreign_currency_preview.dart"
    authority = "lib/storage/waffra_verified_finance_authority.dart"
    encrypted = "lib/storage/waffra_verified_encrypted_finance_bridge.dart"
    production = "lib/storage/waffra_production_cutover_release_gate.dart"

    # All three live SMS confirmation entry points must use the verified
    # source authority; a single remaining instance is not enough.
    home = sources.get(main, "")
    if home.count("_financeAuthority.commitConfirmedSms(") != 3:
        problems.append(f"{main}: a bank SMS confirmation path bypasses verified source authority")

    for marker, reason in (
        ("_financeAuthority.saveCaptured(", "manual save bypasses verified finance authority"),
        ("_financeAuthority.commitConfirmedSms(", "SMS save bypasses verified finance authority"),
        ("waffraCanAssignManualCategory(", "manual category leaf validation missing"),
        ("waffraAmountFieldError(", "mandatory finance amount validation missing"),
        ("bankSmsHasUnverifiedTimestamp", "ambiguous bank date fail-closed missing"),
        ("WaffraSmsCurrencies.requiresReviewForSarLedger(messages[index])",
         "bulk SMS foreign currency guard missing"),
        ("final verifiedSource=WaffraSmsCurrencies.originalAmount(s);",
         "bank parser SAR amount is no longer verified against source action"),
        ("stagedReceiptCopies", "receipt staging tracking missing"),
    ):
        require(main, marker, reason)

    require(curr, "sourceTotals(", "original-currency separated totals missing")
    require(curr, "final minorTotals=<String,int>{};", "original-currency totals no longer use integer minor units")
    require(curr, "requiresReviewForSarLedger(", "foreign SMS review contract missing")
    require(curr, "originalAmount(", "conservative bank amount evidence missing")

    # Check only the actual foreign-FX preview handler, not unrelated app writes.
    home = sources.get(main, "")
    start = home.find("Future<void> _previewForeignBankCurrency(")
    end = home.find("Future<bool> _canReviewOcrAsLedgerTransaction(", start)
    if start == -1 or end <= start:
        problems.append(f"{main}: FX preview handler boundary missing")
    else:
        section = home[start:end]
        if "WaffraForeignCurrencyPreview.show(" not in section:
            problems.append(f"{main}: source-stamped FX approval preview missing")
        if any(token in section for token in (
            "commitConfirmedSms(", "saveCaptured(", "entries.insert(", "persist(",
        )):
            problems.append(f"{main}: FX preview must never write the live ledger")

    require(fx, "quote.provider", "FX preview must display quote provider")
    require(fx, "sourceTimestampUtc", "FX preview must display source timestamp")
    require(fx, "if(accepted!=true)return null;",
            "FX preview does not refuse unapproved quote")
    require(fx, "onPressed:()=>Navigator.pop(dialog,true)",
            "FX preview does not expose an explicit approval action")
    require(fx, "userConfirmed:true",
            "FX review witness no longer requires confirmed user approval")
    require(ai, "WaffraAskScope.isRelated(q)",
            "Ask Waffra can send off-topic questions to model")
    require(ai, "hasUnverifiedMoneyClaim(cleaned)",
            "AI unverified monetary number rejection missing")
    require(model, "static bool hasUnverifiedMoneyClaim(",
            "unverified-model-money guard missing")

    for marker, reason in (
        ("this.encryptedSqlWitnessActive = false", "encrypted SQL witness activated"),
        ("this.externalSourceWitnessActive = false", "external finance source activated"),
        ("this.verifiedKeyRecoveryInDevice = false", "device key witness default changed"),
    ):
        require(authority, marker, reason)
    require(encrypted, "this.experimentalEnabled = false",
            "encrypted runtime prototype was activated")
    require(production, "automaticallyActivateSqlCipher => false",
            "SQLCipher production cutover default changed")

    # Warn about coverage loss: all currencies must be individually present.
    currency_source = sources.get(curr, "")
    match = re.search(r"static const supported\s*=\s*<String>\{(.*?)\};",
                      currency_source, flags=re.S)
    codes = set(re.findall(r"'([A-Z]{3})'", match.group(1))) if match else set()
    if len(codes) != 36 or "SAR" not in codes or "AED" not in codes:
        problems.append(f"{curr}: supported 36-currency financial matrix changed")

    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="Print machine-readable result")
    args = parser.parse_args()
    try:
        problems = audit_sources(load_sources())
    except (OSError, UnicodeError) as exc:
        problems = [f"Could not read QA sources: {exc}"]
    report = {
        "result": "FAIL" if problems else "PASS",
        "checks": "financial-critical-source-contract",
        "problems": problems,
        "physical_android_certified": False,
        "sqlcipher_production_certified": False,
    }
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(f"M340 source contract: {report['result']}")
        for problem in problems:
            print(f"::error::{problem}")
        print("NOTICE: source contract is not device QA or SQLCipher production approval.")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
