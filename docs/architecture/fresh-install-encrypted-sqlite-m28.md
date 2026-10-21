# M28 — Fresh-device encrypted SQLite bootstrap (experimental)

## Decision

A new Waffra install should eventually use **encrypted SQLite from its very first financial transaction**. Existing installs must be treated differently and must never be wiped merely because their transaction count is zero.

This milestone is the **first executable, test-gated piece** of that strategy. Nothing is auto-enabled in the released app.

## Conservative decision logic

- Only an installation with NO persisted finance keys, NO unrecognized preference keys, NO old encrypted vault file, NO activation marker, and NO active widget/secondary writer is a fresh candidate.
- An empty 'entries: []' JSON array, a saved goal, budget setting, SMS hash, saved category, profile/account key or unknown setting **all force a legacy review**, even if there are no recorded transactions.
- An encrypted file whose activation marker is absent is an inconsistent/interrupted state requiring recovery; never create a replacement vault/key on top of it.
- Allowed existing preferences are a narrow set of validated language/theme/appearance keys. They are not erased or imported by the new bootstrap.
- The classifier is only a pure decision helper; when production-wired it must use a complete, consistency-checked on-device snapshot and a process/Android-widget writer freeze.

## Empty encrypted tables

The optional fresh-vault bootstrap requires an already opened SQLCipher WaffraEncryptedStore and explicit experimentalEnabled. It creates a *completely empty* v1 finance schema with tables for:

- ledger entries, categories, saving goals, recurring transactions
- receipt association metadata
- app finance settings and SMS deduplication hashes
- schema version and creation timestamp

No user finance records, default categories, fake goals, sample transactions, Firebase configuration or data uploads are created.

SQLite initialization is one database transaction, idempotent on crash-safe reopen, schema-version guarded, and refuses a shadow database containing staged legacy data. It is not a live-storage cutover or a complete CRUD repository.

## Checks

Host tests verify fresh/legacy classification, theme-only eligibility, unknown or even empty finance-key blocking, orphan encrypted vault handling, writer gate, default-disabled protection, empty encrypted first run, idempotent cold reopen, no accidental deletion of an inserted record, unknown schema version refusal, shadow import blocking, invalid amounts and foreign-key rejection.

## Not yet shipped / release prerequisites

1. Android device lifecycle integration: secure key stored in OS-backed storage; no plaintext key; durable finance source selector written only after encrypted database and receipts are ready.
2. Single write layer for **all** finance screens, SMS bulk import, recurring tasks and Android home-widget capture. No simultaneous preference and SQLite writers.
3. Durable rollback/restore plan for interruptions, full storage, key loss, security changes, app upgrades and test user switching.
4. Real-device, widget, first-run, cold-restart and account regression tests; validate all existing-finance vs new-finance state transitions.
5. UI/report query layer, export and recovery, user-visible explicit error handling. Only after these succeed should main.dart storage selection be enabled for a build.

Firebase stays last. No bank-account integration is required or permitted.
