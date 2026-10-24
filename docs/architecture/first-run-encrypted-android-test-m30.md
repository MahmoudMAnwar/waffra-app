# M30 — Device rehearsal for brand-new encrypted finance installations

Runs on the Android emulator, using an exclusively temporary encrypted database:

1. Classify a truly empty first run as eligible. Never classify an existing `entries: []` key as fresh.
2. Initialize empty finance tables via M28; confirm zero transactions and zero totals, with no fake account records.
3. Add one expense and one income using M29's integer-halala repository.
4. Close the encrypted SQLite database, verify the database is not plain SQLite, cold-reopen with the same test-only key and assert records/totals survive intact.
5. Run a second initialization and confirm it is idempotent and non-destructive.
6. Delete one test transaction and verify the remaining amount.
7. Refuse schema creation for an otherwise zero-transaction legacy installation.

All test accounts and entries are ephemeral. No production UI routing, Firebase login, SharedPreferences, mobile financial records or receipts are touched.

**Still blocked for release:** app-wide source selector, secure OS-backed production key derivation, screen and Android widget writer coordination, real backup/rollback, receipts, goal/category CRUD, empty/full disk scenarios, production Android/iOS verification and user-data-safe activation.
