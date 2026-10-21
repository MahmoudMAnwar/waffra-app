# M35 — Atomic encrypted finance snapshot and revision guard

## Why

Current Waffra HomeScreen.persist() writes legacy finance data across multiple SharedPreferences keys, while an independent Android quick-add widget reads/writes two of those keys. The operations are not atomic and can overwrite each other.

M35 adds an **opt-in, TEST-ONLY full finance snapshot** to the existing SQLCipher vault. A single SQLite transaction stores all available financial preference keys plus a monotonic generation, with a SHA-256 checksum for accidental corruption detection.

### Features

- Captures every field recognized by WaffraLegacyPreflight.allKeys (transactions, categories, goals, recurring, challenges, deleted/recycle collections, delayed recurring, learned merchants, SMS dedupe, budgets and reminder toggles).
- Preserves the exact serialized JSON and absent-key markers, rather than resetting goals just because transaction count is zero.
- Validates snapshot shape, amounts and IDs before saving.
- Exposes initializeEmpty(), read(), commit(expectedGeneration, fullFinanceSnapshot).
- SQL transaction atomically replaces all data and advances its generation; concurrent callers using a stale generation fail instead of overwriting later changes.
- Survives cold reopen; repeated initialization doesn't erase data. Refuses mismatched schema and shadow-migration databases.
- A checksum is NOT a keyed authentication tag; SQLCipher key management and independent backup remain necessary.

## Not production ready

- Neither HomeScreen nor Android widget invokes this API yet.
- Callers must hold the same M34 exclusive writer gate, read the current snapshot after taking the gate, apply their narrow change, and commit using its expected generation. No caller may save cached full-screen finance state over another writer's revision.
- Real activation requires complete offline data-source selection, crash recovery, updated receipts and UI models, migration from existing preference keys, and a verified rollback path.
- Standalone key-value finance snapshots are not a replacement for final normalized relational schema. They are an atomic, lossless bridge into it.
- Never save raw bank account identifiers or direct bank integrations; Firebase comes last.

Tests are synthetic and use temporary encrypted SQLite files only.
