# M26 — verify mapped receipt files against encrypted relational records

M26 connects the disposable receipts copied by M25 with a fresh, **disposable encrypted** SQLite vault. This is a dress rehearsal for the required future database/file cutover, not an activation mechanism.

1. Require explicit `experimentalEnabled: true`, an isolated vault identifier, real copied-file directory and authenticated M16 backup preview.
2. Confirm old and new finance snapshots differ only in `receiptPath`; preserve transaction IDs, titles, categories, dates, amounts and all non-entry finance fields.
3. Validate that every remapped filename is SHA-256-derived from the exact `[entryId, receiptIndex]` association and points into the one supplied disposable directory.
4. Verify every copied file is present, is a regular file (not a symlink), contains the exact authenticated backup bytes, and reject unexpected files.
5. In ONE database transaction: import the rewritten snapshot, project it into encrypted relational tables, compare ledger counts and income/expense totals, verify `entry_receipts` SQL references match the actual copied paths, then re-audit the filesystem before the DB commit.
6. Return counts and halala totals only; never report transaction names or source paths to logs.

### Limits and release gates

- Database atomicity is not filesystem atomicity. Never use this code to mutate an active vault or install files in a user's live receipt directory.
- Caller MUST provide single-writer disposable storage and discard both trial targets on any failed rehearsal.
- A production-ready crash-safe installer still needs a durable *cross-resource* activation pointer, an inactive encrypted vault, full writer freeze (including Android widget writers), forced-interruption rollback tests, low-disk handling, app UI/account collision policy and explicit user permission.
- Android/iOS real-device tests, full regression, rollback and safe backup recovery are mandatory before switching Waffra's read/write storage source. Keep the stacked PRs in draft until these gates are green and reviewed.
- Firebase remains entirely deferred until the offline storage migration path is production safe.
