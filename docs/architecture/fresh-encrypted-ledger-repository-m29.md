# M29 — Fresh encrypted ledger repository prototype

M28 safely initialized an empty encrypted SQLite schema for **truly new installs** in a disabled test-only flow. M29 provides the first real CRUD access layer for **transaction records**, still isolated from production data and running UI.

## Implemented

- Exact integer halala amounts in SQLCipher, with immutable IDs, title, category snapshot, income/expense flag and ISO timestamp.
- Add, list (latest first), replace, remove and aggregate count/income/expense amounts.
- Single-transaction update/delete and fail-closed error handling: missing records, duplicate IDs, invalid amounts, dates, schema version, disabled gate and uninitialized vaults are rejected.
- Delete and update operations refuse attachment-bearing transactions until a separate receipt lifecycle is in place.
- Stable records survive encrypted database cold-reopen; stored original-style JSON is generated from typed fields. No sample financial records are inserted at bootstrap.
- Automated tests for the above, including Arabic values and exact income/expense halalas.

## Remaining

This is not a deployed migration or read/write source switch. Do **not** attach it to main.dart, widget capture or SMS processing without:
1. Durable storage source selection that never overwrites an existing user's SharedPreferences.
2. Cross-isolate/widget writer coordination and receipt file transaction/recovery.
3. Dedicated repository APIs for categories, goals, recurring, challenges, recycle bin, settings and deduplication hashes.
4. End-to-end UI consistency tests for manual transactions, bank SMS, analytics and PDF exports.
5. Mobile device crash/cold-start, wrong key, disk full and backup/rollback tests.

There is no Firebase integration here; it remains the final separate milestone.
