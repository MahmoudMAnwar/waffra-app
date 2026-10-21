# M55 — Transactional, verified encrypted receipt staging

This milestone combines M52's immutable finance snapshot witness, M53's app-private receipt path constraints and M38's SQLCipher encrypted receipt BLOB format.

When explicitly enabled for an **isolated test vault**, the stager:

- Acquires Waffra's existing app/widget writer file lock and reads the current legacy finance data after any pending widget-journal recovery.
- Refuses to proceed unless the separate SQLCipher whole-finance snapshot exactly matches the legacy snapshot at generation 1.
- Projects every original transaction, with its original JSON, date, exact integer-halalah amount and type into encrypted relational ledger records.
- Copies each existing image byte array under a trusted app-private directory into SQLCipher's `fresh_finance_receipt_blobs` table with SHA-256 digest, length and stable owner/position.
- Inserts transactions and ALL receipt BLOBs in a **single SQL transaction**; a missing file, invalid amount, out-of-root path, changed image, duplicate projected record or checksum mismatch aborts and rolls back the entire projection.
- Reads every encrypted BLOB back and verifies its byte length/hash, income/expense totals and record counts.
- Confirms the original SharedPreferences finance checksum is still unchanged before commit.

Tests include Android-compatible encrypted-file cold reopen, preserved Arabic transaction JSON, byte parity, missing image rollback, stale/occupied vault rejection and default-disabled behavior.

## Remaining before real activation

The original snapshot JSON still contains legacy `receiptPath` values. This stager does **not** rewrite them or delete the old files: app UI image loading, PDF/backup, imported receipts, saved-goal history, widget and SMS routes must all use the new encrypted source and receipt IDs before any real cutover marker can be set.

Also required: secure OS key/recovery, two-witness durable activation, independent backup/rollback, real Android UI and release APK validation. Firebase is ready separately; no Firebase or bank-account integration was modified here.
