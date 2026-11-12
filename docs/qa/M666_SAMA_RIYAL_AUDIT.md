# M666 — SAMA Saudi Riyal symbol all-surface audit

Source: Saudi Central Bank (SAMA), [official Usage Guidelines PDF](https://www.sama.gov.sa/ar-sa/Currency/SRS/Documents/Guidelines.pdf), pp. 16–17. Owner request 12 November 2026; tracked by [Issue #596](https://github.com/MahmoudMAnwar/waffra-app/issues/596) and [Draft PR #597](https://github.com/MahmoudMAnwar/waffra-app/pull/597).

## Interpretation and source boundaries
- Show the official original Saudi Riyal mark **physically left of the number** in Arabic RTL and English LTR, with visible space; left of the minus sign for negatives, without horizontal mirroring or black replacement glyphs.
- A textual code such as `SAR` in foreign-exchange calculations, structured imports, native bank messages, ISO APIs or machine-readable storage is **not** the user-facing Riyal mark. Preserve those financial facts and strings.
- Pure Flutter, PDF and Android widget visual presentation must be checked separately. Source assertions and CI green do **not** prove on-device pixels.

## Source audit and remediation matrix
| Surface | Source path or component | Initial condition | Current proposed correction | Verification |
|---|---|---|---|---|
| Home balance, dashboard totals, category report values | `lib/main.dart` `RiyalAmount` / `WaffraCurrencyAmount` | Explicit LTR row had **number before symbol** | Render original official SAR PNG, gap, signed number in LTR row; privacy-eye unchanged | Source corrected; RTL/LTR widget and device visuals unverified |
| Transaction activity cards | `lib/main.dart` `tile` | Separate amount text and currency caption, not fixed left-to-right layout | One signed amount component, symbol at physical left | Source corrected; activity layout pending device |
| Reports and exports | `lib/main.dart` `pdfMoney` / `pdfCurrencyMark`; `lib/waffra_pdf_text.dart` | Number precedes currency mark, English falls back to SAR; PDF text sanitizer substitutes unsupported glyph in imported prose | Fixed LTR icon + gap + text row; embed existing approved PNG for **both** languages; no edits to original prose sanitizer | Source corrected; PDF rendered pages/print magnification must be visually inspected |
| Mixed Arabic/English amount labels (goals, dues, budgets, Smart Analysis, SMS summaries) | `lib/waffra_riyal_symbol.dart`; `lib/waffra_i18n.dart` | Currency replacement retained original token position, English was plain SAR | Bind prefix/suffix unit+number as one fixed-LTR inline display run with official mark, without rewriting original SMS | Source corrected; widget and end-to-end RTL/LTR pending |
| Calendar and recurring-finance tool cards | `lib/waffra_financial_tools.dart` | Number and icon vertically stacked | Compose fixed LTR icon + signed amount; other inline WaffraText values use shared renderer | Source corrected; 320dp/large font pending |
| Account list, balances, account budget/goal context | `lib/waffra_accounts_manager_page.dart`, `lib/waffra_home_accounts_sheet.dart`, `lib/waffra_account_context_page.dart` | Raw Text of amount+SAR bypassed central mark renderer | Route user-visible financial amounts through `WaffraText` and central mark | Source corrected; real screens pending |
| Utilities, financial reconciliation, oil/gold SAR estimates | `lib/waffra_practical_tools_page.dart`, `lib/waffra_oil_market_section.dart`, `lib/waffra_gold_market_section.dart`, `lib/waffra_gold_calculator.dart` | Independent amount+SAR/ريال strings; some raw Text | Adjust raw Text paths; remaining SAR-specific WaffraText goes through shared renderer. Do not replace actual USD/FX values | Source partly corrected; verified quote and cross-currency screens pending |
| Native launcher home widget | `native/WaffraWidget.kt`, `.github/workflows/android*.yml` generated XML | Approved icon stacked below amount, English only showed SAR | Fixed horizontal LTR icon-left row, 3dp spacing, mark for Arabic/English, preserve privacy hiding | Source corrected; actual launcher 1x1/RTL Android pending |
| Saved transaction system notification | `native/WaffraAutoSmsNotifications.kt` | `amount ر.س` right-side abbreviation | U+20C1 mark-left with LTR isolate; safe ISO SAR fallback when OS font lacks glyph; preserve private/redacted notifications | Source corrected; OS/browser font and right-to-left notification pending |
| Editable financial inputs and original SMS | Money editor, encrypted ledger, SMS source | Financial data text and amount parsing; neither is a display-only SAR badge | **No broad rewrite**; keep original spelling and numeric authority | Deliberately unchanged; regression required |

## Mandatory acceptance checks before recommending merge
- Exact latest PR SHA: `flutter analyze` and complete Flutter/unit/widget tests, M385 and M550 behavior/scope, M449 approved release-note freshness, M147 native Android compilation, SQLCipher/finance integration. Failures are reported and fixed; no test skipped intentionally.
- Geometry tests verify **mark-right-edge less than numeral-left-edge** for positive, negative, zero, Arabic-Indic, Western digits and prefix/suffix SAR in both app locales.
- PDF page-level screenshots verify symbol fidelity, proportional height and contrast at small size, no tofu/black square, Arabic/English and signed columns.
- Physical Android screenshots at 320/393dp, light/dark, text scale, 1x1 launcher widget and notifications, full goal/due breakdown, transaction cards and reports. Screen-reader semantics and privacy-eye behavior remain intact.
- User/device approval remains distinct from CI. Mark each item **Pass / Fail / Unverified** only after concrete evidence is captured.

**Current state:** Source corrections underway in PR #597; automated CI, PDF visual checks and physical device results must be assessed independently. No claim of whole-app production compliance.
