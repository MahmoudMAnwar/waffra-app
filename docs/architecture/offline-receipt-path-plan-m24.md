# M24 — Verified offline receipt path remapping plan

The historic MoneyEntry.receiptPath may contain one phone-local path or an encoded ordered array of multiple paths. These paths must NOT be replayed as filenames onto another device.

`WaffraOfflineReceiptPathPlanner.plan` takes an authenticated M16 preview, M19 staged attachments, M20 independently audited receipt bytes, and a new empty real app-private destination. It revalidates source-finance checksum and audit, creates a copied in-memory financial snapshot, and substitutes SHA-256-derived private destination paths without using entry IDs or old absolute paths as file names.

The planner:
- Blocks by default.
- Rejects nonempty/unsafe targets, altered files, missing receipt mappings and receipt count mismatches.
- Preserves original transaction IDs, dates, income/expense amounts and nonreceipt finance fields.
- Preserves multiple receipt order.
- Never touches user files, live SharedPreferences, existing SQLite vault, or Firebase.
- Never claims the planned files already exist. The destination remains empty until a separately verified installer is implemented.

## Before a production cutover
A live installer must stage/copy file bytes to the target, re-audit their contents, freeze ALL legacy writers, commit receipt path remapping and financial data together with a crash-safe atomic activation/rollback mechanism, and restore old state after failure. Android/iOS end-to-end tests, storage-full/process-death injection, user-confirmed vault selection, and owner release approval are mandatory.

This remains a safe experimental plan in a draft PR. Firebase comes last.
