# M416 — Saudi-only offline release acceptance (Draft)

## Owner-approved scope
- SAR-only presentation and Saudi Arabic wording; English app language remains usable. No country/location/currency/dialect selectors in the Saudi edition.
- Never request location on cold start, returning Google sign-in, guest mode, restoring a backup, or opening settings. Bypass first-run country/setup screen.
- Keep all Global code and stored legacy currency/region preferences. Do not clear prefs, alter ledger amounts, rewrite finance storage, or migrate existing financial data.
- Hide receipt/image OCR transaction creation from plus; guard scanner and scanned transaction editor. Preserve original receipt attachments, galleries and manual transaction attachments.
- Bank SMS paste/share is deterministic/offline only; no Qwen inference, download, readiness check or cancel. Review and explicit save still required. Maximum 100 SMS per paste; preserve duplicate detection and source date checks. Foreign currencies must never save as SAR.
- Ask Waffra has predefined financial questions only: current-month income, spending, net recorded cashflow (not bank balance), most-expensive category, per-category totals and budgets. No freeform chat, keyboard, model or network. Clear shows questions again.
- Hide global currency converter (also gold value FX button) while preserving gold/oil sections.
- Hide international dialing-code picker for Saudi new profiles without rewriting previously stored phone numbers.

## Exact HEAD test matrix
1. Run Flutter analyzer, all finance/UI/SMS tests and test/m416_saudi_release_offline_test.dart; record passed/failed/skipped counts and distinct defect count.
2. Fresh and existing Google login, including previously pending old country setup: no location permission dialog and no country/currency onboarding. Android app permissions unchanged by navigation.
3. My Account: no editable currency/country/dialect controls, AR/EN works and every cash value and PDF displays SAR.
4. Plus menu on Home: manual and bank SMS available; receipt scan absent. Bypassed OCR handler and editor fail closed. Historic receipt attachments still open.
5. Test representative Saudi Arabic and English bank SMS with SAR evidence, balance/card decoys, reversals, multiple messages, bad timestamps, duplicates; with Qwen absent/installed/downloading; results must be identical and save only after explicit review.
6. Foreign/mixed-currency SMS: safely reject foreign amount instead of converting it, and remove live FX quote action.
7. Ask Waffra without Qwen: show selectable questions; financial answers from current account-scoped finance snapshots only, including explicit named-budget spent. Clear returns to questions. Empty data, pause, backup, edit/delete and locale checks.
8. Tools: currency exchange panel hidden; gold and oil remain available. No forced model download.
9. In-place upgrade: all transactions, goals, recurring schedules, categories, budgets, attachments, Google sign-in and encrypted backups remain intact.
10. Signed physical Android tests: phone sizes, 3-button/gesture system bars, app restart, dark/light, Arabic/English, Play Data Safety/permission review.

## Release gates
Keep PR Draft until exact-head CI and physical-device evidence. No automatic merge to main or production-store release. Reconcile with #348 and #350; do not overwrite their UI/alert changes.
