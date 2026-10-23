# M128: Disposable SQLCipher category and recurring fail-closed QA

**Scope:** independent test-only follow-up to M127, based on its exact review
branch. No runtime code, Google Sign-In configuration, user records, migration,
production SQLCipher activation, release, or `main` merge is changed.

The tests initialize a **new disposable encrypted SQLite vault** with
`experimentalEnabled: true` only in the test harness, seed canonical snapshot
data using the guarded UI writer, then deliberately corrupt typed SQL columns
or delete projection rows while keeping canonical JSON unchanged.

Negative acceptance checks:

1. A forged category `budget_minor` blocks a Home category update; its SQL
   tamper remains visible for recovery and the snapshot generation, digest and
   values remain byte-for-byte logically unchanged.
2. A missing category SQL row blocks a combined update/new-category request
   without creating a replacement.
3. A forged recurring `due_day` blocks a recurring update **after** a new
   category was attempted in the same transaction; that category insertion
   must roll back.
4. A forged recurring `amount_minor` blocks an edit without auto-repair.
5. A missing recurring SQL row blocks update plus create atomically.

The checks live in
`test/storage/m128_sqlcipher_category_recurring_fail_closed_test.dart` and
`test/storage/m128_sqlcipher_recurring_rollback_test.dart`. The existing
`finance-full-regression.yml` pull-request job runs `dart analyze lib/storage
test/storage` and `flutter test test/`, including both files. Do not manually
dispatch the same job if the pull-request event has already scheduled it.

**Acceptance:** only GitHub Actions runs with `conclusion=success` for the
exact M128 PR head SHA count as passing. Tests are not evidence of physical
device certification or authorization to activate SQLCipher for users.
