#!/usr/bin/env python3
"""M227 strict latest-main, protected SMS and global-gold reconciliation QA.
This audit CANNOT approve 24-route SQLCipher deployment or real-phone QA.
"""
from __future__ import annotations
import json
import os
from pathlib import Path
import subprocess

MAIN = "27f0bf96b9af68ef325b50a5508c2f8cac465694"
FEATURE = "5a1ceb3d8c34d65582a596bf4fbb67d66b02e2d8"
ALLOWED = {
  ".github/workflows/m147-final-main-review-gate.yml",
  "docs/release/WAFFRA_APPROVED_CHANGES.txt",
  "integration_test/m202_home_widget_source_binder_android_test.dart",
  "lib/currency_converter.dart",
  "lib/main.dart",
  "lib/storage/waffra_encrypted_sms_notes_vault.dart",
  "lib/storage/waffra_home_finance_persistence.dart",
  "lib/storage/waffra_production_finance_authority_binding.dart",
  "lib/storage/waffra_restored_finance_receipt_attestor.dart",
  "lib/storage/waffra_verified_finance_authority.dart",
  "lib/waffra_display_currency.dart",
  "lib/waffra_gold_market_data.dart",
  "lib/waffra_gold_market_section.dart",
  "scripts/qa/m227_gold_currency_original_sms_main_review.py",
  "test/m224_pdf_verified_display_currency_test.dart",
  "test/m224_verified_gold_fallback_test.dart",
  "test/m225_currency_flags_gold_ui_test.dart",
  "test/m227_gold_currency_original_sms_home_test.dart",
  "test/storage/m109_verified_finance_authority_test.dart",
  "test/storage/m226_encrypted_original_sms_sidecar_test.dart",
  "test/storage/m226_encrypted_sms_authority_integration_test.dart",
  "test/storage/portable_encrypted_vault_restorer_test.dart",
  "test/storage/production_finance_authority_binding_test.dart",
  "test/waffra_widget_quick_capture_test.dart"
}

def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True).strip()

def need(ok: bool, why: str) -> None:
    if not ok: raise SystemExit("M227 QA BLOCKED: " + why)

def main() -> None:
    head = git("rev-parse", "HEAD")
    need(head == os.environ.get("REVIEW_HEAD_SHA",""), "head SHA mismatch")
    origin_main = git("rev-parse","refs/remotes/origin/main")
    need(origin_main == MAIN, "main moved; fresh reconciliation required")
    merge = git("rev-parse","HEAD^")
    parents = git("rev-list","--parents","-n","1",merge).split()[1:]
    need(parents == [MAIN,FEATURE], "integration must preserve latest main + M225 ancestry")
    changed = set(filter(None,git("diff","--name-only",MAIN,head).splitlines()))
    need(changed == ALLOWED, "unreviewed paths: " + repr(sorted(changed ^ ALLOWED)))
    need(not any(x.startswith(("native/","firebase/")) for x in changed),
         "native or cloud production changes forbidden")
    need(not any(x in changed for x in ("pubspec.yaml","pubspec.lock","android/app/google-services.json")),
         "no security dependency or production credential change permitted")
    source = Path("lib/main.dart").read_text(encoding="utf-8")
    vault = Path("lib/storage/waffra_encrypted_sms_notes_vault.dart").read_text(encoding="utf-8")
    bridge = Path("lib/storage/waffra_verified_finance_authority.dart").read_text(encoding="utf-8")
    persist = Path("lib/storage/waffra_home_finance_persistence.dart").read_text(encoding="utf-8")
    bind = Path("lib/storage/waffra_production_finance_authority_binding.dart").read_text(encoding="utf-8")
    currency = Path("lib/waffra_display_currency.dart").read_text(encoding="utf-8")
    converter = Path("lib/currency_converter.dart").read_text(encoding="utf-8")
    gold = Path("lib/waffra_gold_market_section.dart").read_text(encoding="utf-8")
    notes = Path("docs/release/WAFFRA_APPROVED_CHANGES.txt").read_text(encoding="utf-8")
    release = Path("lib/storage/waffra_production_cutover_release_gate.dart").read_text(encoding="utf-8")
    checks = {
      "full original in verified detail": ("readProtectedOriginalSms(entry.id)" in source
         and "child:SelectableText(entry.notes" in source),
      "gold on home": ("waffra-home-gold-currency-entry" in source
         and "محوّل العملات وأسعار الذهب العالمية" in converter
         and "WaffraGoldMarketSection(" in converter),
      "global nominal display only": ("provider: 'display-only'" in currency
         and "if(code=='SAR'||displayOnly)return amount.toDouble();" in currency
         and "double? toLedgerSar" in currency),
      "original protected with OS key": ("FlutterSecureStorage" in vault
         and "WaffraEncryptedStore.openAt" in vault
         and "readVerifiedEntry" in vault
         and "await store.transaction" in vault),
      "legacy never gets raw SMS": ("protectedNotesBeforeLegacyCommit:" in bridge
         and "Map<String, Object?>.unmodifiable({...record, 'notes': ''})" in bridge
         and "WaffraLegacySmsNotesPrivacyGate.rejectConfirmedSmsNotes(copied)" in persist),
      "home and widget bound": ("protectedSmsNotes: const WaffraEncryptedSmsNotesVault()" in bind
         and "readProtectedOriginalSms" in bridge),
      "UI frozen direction/press": ("WaffraStationaryFabAnimator()" in source
         and "waffraMotion(165)" in source and "waffraMotion(110)" in source
         and "Duration(milliseconds:380)" in source),
      "no cutover activation": ("automaticallyActivateSqlCipher => false" in release),
      "notes M227": ("[M227]" in notes and "SQLCipher" in notes),
      "gold source verified": ("Gold bars" in gold and "أسعار الذهب العالمية" in gold),
    }
    need(all(checks.values()),"missing required implementation: " +
         repr([k for k,v in checks.items() if not v]))
    result = {
       "scope":"M227-exact-main-gold-nominal-and-sms",
       "main_sha":MAIN,"source_head":FEATURE,"reviewed_sha":head,
       "merge_commit":merge,"checks":checks,
       "changed_paths":sorted(changed),
       "legacy_plaintext_sms_allowed":False,
       "sqlcipher_all_routes_production_certified":False,
       "two_android_phones_verified":False,
       "production_release_authorized":False,
    }
    out=Path("build/m147-final-review-report.json")
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(result,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
    print(json.dumps(result,ensure_ascii=False,indent=2))
if __name__ == "__main__": main()
