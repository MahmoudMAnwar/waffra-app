# M470 — Arabic text / Riyal-token corruption audit

## Scope (2026-11-06)
Static source review of all **241** Dart files under `lib/` (115 app/UI/logic, 124 storage, two diagnostics) and all **7** native Kotlin files. We screened for the ambiguous Arabic SAR abbreviation expression, U+FFFD replacement characters and U+202A–U+202E / U+2066–U+2069 directional overrides. This is a code audit, **not** an assertion that every visual widget has passed a signed-device inspection.

## Root cause
The former SAR expression `ر\\.?\\s*س` treated the first two letters `رس` of ordinary Arabic words such as `رسالة`, `رسائل`, `رسوم` and `رسم` as a currency abbreviation. The `WaffraText` path then replaced those letters with the Riyal image when a number was adjacent, visibly corrupting sender counts and transfer-fee summaries. Related classifiers also risked treating ordinary text as currency evidence.

## Corrected locations
1. `lib/waffra_riyal_symbol.dart` — presentation-only replacement; now requires complete standalone currency tokens, not an arbitrary word prefix.
2. `lib/main.dart` — corrected `BankParser` currency token plus Arabic sender-review labels (`رسائل للمراجعة`; `رسائل بانتظار المراجعة`).
3. `lib/waffra_sms_multicurrency_review.dart` — complete Arabic SAR token in verified original-amount extraction.
4. `lib/waffra_ai_finance_brain.dart` — no false competing finance amounts from `رس...` words.
5. `lib/waffra_auto_sms_policy.dart` — no financial auto-post eligibility based solely on a word that begins with `رس`.
6. `lib/waffra_bank_screenshot_parser.dart` — no OCR amount extracted from `500 رسالة` without an actual currency.
7. `lib/waffra_bank_sms_facts.dart` — fee currency suffix cannot consume the beginning of another word.
8. `lib/waffra_cloudflare_sms_gateway.dart` — SAR source-unit fallback only for an actual Arabic Riyal token.
9. `lib/waffra_sms_cloud_redactor.dart` — currency evidence before cloud suggestion cannot be an Arabic word fragment.

No matching unsafe abbreviation or scanned invalid text controls were found in the other inspected Dart and Kotlin source files. This does not prove there are no unrelated typography, layout, font fallback, line wrapping, PDF or Android OEM issues.

## Added regression coverage
- `test/m470_arabic_currency_word_boundary_test.dart`: display regression for SMS counts, sender names, separate fees, English/SAR representations and Riyal artwork.
- `test/m470_financial_currency_word_boundary_regression_test.dart`: scans all Dart source for the old unsafe regex and U+FFFD; checks strict SMS policy, OCR, cloud redaction and source-currency logic against false `رسالة` evidence and positive real SAR examples.

## Signed Android QA required before claiming complete resolution
- Arabic and English, dark/light, standard and increased font scaling.
- 500 / 497 / 3 SMS counters and every sender row, including mixtures of Arabic text and English sender names.
- One transfer with account suffixes and a separate SAR fee; verify original monetary evidence is not changed and no duplicate writes happen.
- Income and expense review dialogs, mixed-direction original SMS, category selector, account selector and rule previews.
- All balance/statistics cards, tools, goals, recurring, budgets, reports/PDF and native Android widget.
- Recheck original message contents remain untouched: this change is only token matching/display and verification, not SMS mutation.

**Status:** Changes committed on a development branch; no exact-head Flutter tests, CI success, main merge or signed APK certification claimed.
