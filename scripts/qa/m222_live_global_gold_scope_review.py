#!/usr/bin/env python3
"""M222 exact-head, only-approved-UI live XAU spot safety review."""
import json
import os
import subprocess
from pathlib import Path

SCOPE = {
    ".github/workflows/m147-final-main-review-gate.yml",
    "docs/qa/m222-live-gold-spot-currency-tool.md",
    "docs/release/WAFFRA_APPROVED_CHANGES.txt",
    "lib/currency_converter.dart",
    "lib/waffra_gold_market_data.dart",
    "lib/waffra_gold_market_section.dart",
    "scripts/qa/m222_live_global_gold_scope_review.py",
    "test/m222_gold_spot_currency_integration_test.dart",
}

def git(*args):
    return subprocess.run(["git", *args], check=True, text=True,
                          capture_output=True).stdout.strip()

def require(value, label):
    if not value:
        raise SystemExit("M222 BLOCKED: " + label)

def read(path):
    return Path(path).read_text(encoding="utf-8")

def main():
    head = git("rev-parse", "HEAD")
    base = git("rev-parse", "refs/remotes/origin/main")
    require(head == os.environ.get("REVIEW_HEAD_SHA", "").strip(),
            "the reviewed commit must match the exact PR head")
    require(git("merge-base", base, head) == base,
            "the exact review branch is not based on current main")
    changed = set(filter(None, git("diff", "--name-only", base, head).splitlines()))
    require(changed == SCOPE,
            "unexpected files: " + repr(sorted(changed ^ SCOPE)))

    currency = read("lib/currency_converter.dart")
    quotes = read("lib/waffra_gold_market_data.dart")
    gold_ui = read("lib/waffra_gold_market_section.dart")
    tests = read("test/m222_gold_spot_currency_integration_test.dart")
    workflow = read(".github/workflows/m147-final-main-review-gate.yml")
    notes = read("docs/release/WAFFRA_APPROVED_CHANGES.txt")
    guide = read("docs/qa/m222-live-gold-spot-currency-tool.md")
    gate = read("lib/storage/waffra_production_cutover_release_gate.dart")

    for key in (
        "import 'waffra_gold_market_section.dart';",
        "WaffraGoldMarketSection(english:waffraIsEnglish)",
        "void swapCurrencies()",
        "Future<void> convert()",
        "ExchangeRate-API",
    ):
        require(key in currency, "existing currency workflow or gold insertion missing: "+key)

    for key in (
        "31.1034768",
        "24: 0.999",
        "22: 22 / 24",
        "21: 21 / 24",
        "18: 18 / 24",
        "14: 14 / 24",
        "Uri.https('api.gold-api.com', '/price/XAU')",
        "json['symbol'] != 'XAU'",
        "json['currency'] != 'USD'",
        "json['updatedAt']",
        "Future<WaffraGoldSpotQuote> fetch(",
        "response.bodyBytes.length > 131072",
        "const Duration(seconds: 12)",
        "isOlderThan",
    ):
        require(key in quotes, "global spot data contract broken: "+key)

    for key in (
        "class WaffraGoldMarketSection extends StatefulWidget",
        "waffra-global-gold-market-section",
        "waffra-gold-quote-error",
        "waffra-gold-calculated-value",
        "waffra-gold-calc-weight",
        "waffra-gold-karat-",
        "أسعار الذهب العالمية",
        "عيار",
        "سبيكة",
        "الجرام",
        "المصنعية",
        "troy",
    ):
        require(key in gold_ui, "approved Arabic/English gold UI missing: "+key)

    for forbidden in (
        "SharedPreferences", "FirebaseAuth", "FirebaseFirestore",
        "setMockInitialValues", "activateSqlCipher", "sqlcipher",
        "readSms", "bankCredential",
    ):
        require(forbidden not in quotes and forbidden not in gold_ui,
                "price UI must not access finance, auth, local source or SMS: "+forbidden)
    require("WaffraGoldSpotService" in gold_ui and
            "Future<WaffraGoldSpotQuote>" in gold_ui,
            "no verified quote source bound to widget")
    require(tests.count("test(") + tests.count("testWidgets(") >= 13,
            "insufficient gold spot and widget regression coverage")
    require("M222 SHA-pinned" in workflow and
            "m222_live_global_gold_scope_review.py" in workflow,
            "exact SHA CI scope gate missing")
    require("[32] M222" in notes, "gold addition missing from approved release manifest")
    require("SQLCipher" in guide and "NO-GO" in guide,
            "production security boundary missing")
    require("bool get automaticallyActivateSqlCipher => false;" in gate,
            "production encrypted source must remain disabled")

    report = {
        "milestone": "M222", "head": head, "main": base,
        "file_scope": sorted(changed),
        "live_xau_source": True,
        "raw_karat_and_bullion_values_only": True,
        "no_banking_or_sms_access": True,
        "sqlcipher_production": "NO_GO",
        "apk": "NOT_AUTHORIZED_BEFORE_MAIN_SHA_CI",
    }
    path = Path("build/m147-final-review-report.json")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(report))

if __name__ == "__main__":
    main()
