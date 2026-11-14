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
    "lib/waffra_home_entry_sheet.part.dart",
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


def _registered_home_entry_source(sources: Mapping[str, str], problems: list[str]) -> str:
    """Inspect the real, registered same-library Home editor, never a stub.

    M719 moved the verified finance editor byte-for-byte into a Dart part.
    Reinsert its *existing* method at the original marker so the previous
    SMS, date, foreign-currency, receipt and writer checks remain unchanged.
    Missing, detached or duplicate code fails closed.
    """
    main = sources.get("lib/main.dart", "")
    path = "lib/waffra_home_entry_sheet.part.dart"
    declaration = "part 'waffra_home_entry_sheet.part.dart';"
    marker = (
        " // M719: original verified transaction entry form extracted "
        "to same-library Home part.\\n"
    )
    # This is a source assertion, not a substitute for Dart analyzer checks.
    if main.count(declaration) != 1 or main.count(marker) != 1:
        problems.append("lib/main.dart: registered M719 finance editor missing/duplicated")
        return main
    part = sources.get(path, "")
    start_marker = " Future<void> entrySheet("
    start = part.find(start_marker)
    end = part.rfind("\\n}")
    if (not part.startswith("part of 'main.dart';")
            or "on _HomeScreenState" not in part
            or part.count(start_marker) != 1
            or start < 0 or end <= start):
        problems.append(f"{path}: original verified finance editor missing/duplicated")
        return main
    return main.replace(marker, part[start:end + 1])


def audit_sources(sources: Mapping[str, str]) -> list[str]:
    problems: list[str] = []

    def require(path: str, evidence: str, reason: str) -> None:
        checked = home if path == "lib/main.dart" else sources.get(path, "")
        if evidence not in checked:
            problems.append(f"{path}: {reason}")

    main = "lib/main.dart"
    curr = "lib/waffra_sms_multicurrency_review.dart"
    ai = "lib/waffra_smart_features.dart"
    model = "lib/waffra_ai_recorded_answers.dart"
    fx = "lib/waffra_foreign_currency_preview.dart"
    authority = "lib/storage/waffra_verified_finance_authority.dart"
    encrypted = "lib/storage/waffra_verified_encrypted_finance_bridge.dart"
    production = "lib/storage/waffra_production_cutover_release_gate.dart"

    # All four live SMS confirmations must use the verified encrypted
    # authority. M565 adds the owner's first-pass Yes path: checking only the
    # former three would incorrectly reject a *more* protected finance route.
    # Independently demand its user-confirmed, account-witness and hash guards.
    home = _registered_home_entry_source(sources, problems)
    # M636: two remaining secure SMS routes (confirmed Review and editor).
    # The two old widget/paste paths are deleted, NOT downgraded to plain
    # SharedPreferences. A new writer or missing route must fail this gate.
    if home.count("_financeAuthority.commitConfirmedSms(") != 2:
        problems.append(f"{main}: expected exactly two verified SMS authority writers")
    start = home.find("Future<void> _m565ConfirmSms(")
    end = home.find("Future<void> _reviewAutoSmsCandidates(", start)
    if start == -1 or end <= start:
        problems.append(f"{main}: owner-confirmed SMS review route missing")
    else:
        approved_sms = home[start:end]
        for required in (
            "required ({List<String?>? ids,int? generation}) selectedAccount",
            "selectedAccount.ids!.single",
            "final chosen=selectedAccount;",
            "reviewSmsBudgetLinks([record])",
            "allowDuplicateHashes:false",
            "expectedAccountGeneration:chosen.generation",
            "userConfirmed:true",
            "bankSmsDate(body)==null",
            "original.currency!='SAR'",
            "WaffraAutoSms.acknowledgeCommitted([id])",
        ):
            if required not in approved_sms:
                problems.append(f"{main}: quick SMS review bypasses required authority/approval: {required}")

    editor_start = home.find("Future<void> entrySheet(")
    editor_end = home.find("Future<void> showReceipt(", editor_start)
    if editor_start == -1 or editor_end <= editor_start:
        problems.append(f"{main}: surviving SMS/manual finance editor missing")
    else:
        editor = home[editor_start:editor_end]
        for required in (
            "WaffraSmsCurrencies.requiresReviewForSarLedger(message.text)",
            "if(!smsDateConfirmed)",
            "reviewSmsAccountLinks([result]",
            "expectedAccountGeneration:reviewedAccount.generation",
            "allowDuplicateHashes:explicitlyApprovedSmsDuplicate",
            "userConfirmed:true",
            "final parsedLedger=await WaffraLargeJsonDecode.parse(",
        ):
            if required not in editor:
                problems.append(f"{main}: surviving SMS editor bypasses {required}")
    # Old standalone Widget/paste bank SMS writers are prohibited.
    if "Future<void> bulkSmsSheet(" in home or "WaffraWidgetCaptureApp" in home:
        problems.append(f"{main}: removed unverified SMS paste/widget writer returned")

    # Owner-approved first-time account linkage now happens INSIDE preview
    # before the final Yes; an old post-Yes picker would fail this check.
    reviewed_choice = home[end:home.find("void _receiveSharedSms()", end)]
    for proof in (
        "reviewSmsAccountLinks([trial],smsSender:sender)",
        "key:const Key('m590-sms-choose-account-before-yes')",
        "reviewedAccount?.ids?.single!=null",
        "selectedAccount:reviewedAccount!",
    ):
        if proof not in reviewed_choice:
            problems.append(
                f"{main}: selected money account is not verified before user Yes: {proof}"
            )

    for marker, reason in (
        ("_financeAuthority.saveCaptured(", "manual save bypasses verified finance authority"),
        ("_financeAuthority.commitConfirmedSms(", "SMS save bypasses verified finance authority"),
        ("waffraCanAssignManualCategory(", "manual category leaf validation missing"),
        ("waffraAmountFieldError(", "mandatory finance amount validation missing"),
        ("bankSmsHasUnverifiedTimestamp", "ambiguous bank date fail-closed missing"),
        ("WaffraSmsCurrencies.requiresReviewForSarLedger(message.text)",
         "surviving SMS editor foreign currency guard missing"),
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
    start = home.find("Future<void> _previewForeignBankCurrency(")
    # M640: OCR handler was deleted. The verified manual/SMS editor now
    # immediately follows the still-required foreign-FX preview. Preserve
    # the narrow no-finance-write boundary rather than bypassing the test.
    end = home.find("Future<void> entrySheet(", start)
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
    # M636: model/Ask was removed by owner approval. For safety, reject
    # resurrection of any unscoped generation/installer or off-topic Ask
    # instead of requiring code that must no longer exist.
    for marker in ("WaffraOnDeviceQwen", "WaffraAiModelGate",
                   "WaffraAiFinanceCoach.askWaffra", "WaffraAskScope.isRelated(",
                   "waffra-local-ai-opt-in", "waffra-ai-financial-analysis"):
        if marker in sources.get(ai, "") or marker in home:
            problems.append(f"{ai}: retired AI entrypoint reintroduced: {marker}")
    require(model, "static bool hasUnverifiedMoneyClaim(",
            "archived unverified-model-money guard changed")

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
