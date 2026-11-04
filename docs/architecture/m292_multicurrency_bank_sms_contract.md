# M292 — Approved multi-currency bank-SMS review and encrypted-ledger contract

## Accepted UX
- After Google profile completion, opt-in country identification may suggest a home/display currency (EG → EGP; SA → SAR); never force or frequently change it.
- A bank message has its **own original currency**, which never changes the global currency preference.
- If a batch contains SAR, USD, EGP and EUR, review each original transaction separately; do not sum unlike currencies.
- Suggest income or expense using on-device bank-message analysis. Pending, failed, foreign and ambiguous items remain review-only.
- Present original amount/code, independent timestamped FX quote, source/provider, approximate home-currency equivalent, and explicit per-transaction confirmation.
- A verified spot quote is not necessarily the historical exchange rate or what the issuing bank actually charged; settlement and fees may differ.
- Preserve original amounts, original currency, quote rate, source publication time, selected base currency, rounded target amount and user's approval timestamp. Do not recompute historical approved transactions using latest quotes.
- No original SMS, bank IDs, card numbers, screenshots, GPS or OCR are sent to public FX endpoints; send currency codes only.

## Immutable provenance fields (version 1)
- originalMinor: source amount in original currency's minor units
- originalCurrency: ISO-4217 currency code
- convertedMinor: reviewed base-currency amount in minor units
- convertedCurrency: the base currency at the time of approval
- targetPerOriginal: target units for one original unit
- provider: verified quote source, not a made-up price
- rateTimestampUtc: provider FX quote publication timestamp
- approvedUtc: user approval time

The draft model uses per-currency fraction precision (e.g. JPY has zero decimals, KWD three, SAR/USD/EGP two), rejects expired/negative/non-finite quote data, and never touches the existing finance ledger.

## Release blockers — DO NOT CUT OVER YET
1. Existing MoneyEntry stores one amount with no currency/Fx witness. Add a versioned encrypted currency record in the authoritative SQLCipher ledger, not a plaintext sidecar.
2. Transaction create/edit/delete/undo, atomic SMS journal/hash, snapshots, and receipt links must commit amount + origin + verified FX metadata together. Never write converted amounts alone.
3. Migrate legacy entries without changing any historic numeric value; mark legacy currency assumptions explicitly.
4. Extend encrypted backups, restore across two devices, cloud sync, widgets, budgets, goals, recurring transactions, analytics, PDF/CSV and account summaries to distinguish original and base amounts.
5. Build a multi-message review screen with original amounts and separate currency groups, secure quote retrieval and explicit user approval. Reject ambiguous symbol-only dollar messages, stale FX and mixed/unsupported unverified rates.
6. Test Flutter analyzer, malformed/tampered provenance, network offline, consent/skip, Arabic/English RTL/LTR, Android device, SQLCipher and recovery/rollback. No main merge or APK approval until these pass.

## Delivery status
- M291: conservative currency detection and safe block for automatic foreign-currency posting on the SAR-only legacy ledger.
- M292: a pure draft FX quote and audit-snapshot model with deterministic regression tests; **NOT connected to production financial writes**.
- Follow-on ledger migration and the user-facing multi-currency confirmation experience remain required before marking the feature complete.

## M293 — Encrypted write/backup fail-closed staging (2026-10-28)

- The disconnected `WaffraFreshLedgerRepository` now accepts optional **approved** foreign-currency FX provenance in `source_json` in the **same SQLCipher row/transaction** as the SAR equivalent amount. Historical pre-M293 entries keep their original numeric amount and JSON shape.
- Every entry with an FX witness must carry an explicit user-approval timestamp, original currency/minor amount, SAR converted amount, rate, provider and quote timestamp. SQL read rejects a mismatch between the original JSON/witness and authoritative integer amount.
- The experimental screen gateway passes FX metadata through instead of dropping it, and rejects foreign SMS without reviewed provenance. FX entries cannot yet use generic edit or delete: those actions are blocked until audited Undo, receipts and backup parity exist.
- Portable encrypted restore refuses mismatched original FX witness or converted SAR minor units. Portable backup export refuses FX rows that are not represented identically in its encrypted snapshot rather than silently losing money evidence.
- Source- and SQLite-backed regression tests include cold reopen, amount tampering, blocked edit/delete, backup omission and timestamp corruption. Exact-HEAD GitHub Actions must complete successfully before acceptance.

**This is NOT the production cutover.** The live Home/Widget still share the guarded legacy finance source. OCR on real iOS devices, two physical Android phones, multicurrency UI confirmation, complete atomic snapshot update, cloud sync, all-report/PDF/CSV/goal/recurring parity, and restore/edit/delete/Undo certification remain blocking. No irreversible migration or automatic foreign-currency SMS save is enabled.
