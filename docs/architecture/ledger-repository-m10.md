# M10: Experimental ledger repository (disabled in production)

This change adds `WaffraLedgerRepository` and
`WaffraDraftSqliteLedgerRepository` as a **working model** for eventual
Flutter UI / SMS / widget / recurring persistence.

## What exists now

- Fail-closed `experimentalEnabled=false` by default. No changes to
  `main.dart`, the existing SharedPreferences ledger, or Firebase.
- `prepareVerifiedVault` copies a **verified** immutable relational ledger
  projection into a separate encrypted SQLite working table, in a single
  transaction with count and income/expense parity checks.
- Repeating preparation never resets edits, and never overwrites the original
  source JSON or the migration audit.
- Versioned create/update/delete/restore with optimistic expected-version
  checks; cannot resurrect a deleted entry via an ordinary edit.
- Integer halala totals, original transaction date string, local calendar day
  validation and per-vault isolation.
- All writes cooperate with M9's write gate. Financial dashboards/report data
  cannot be switched to this store until all writers and readers are routed
  through the same app-wide repository.

## Test scenarios

- Disabled feature and missing projection refused
- Exact import parity, re-initialization, unchanged legacy JSON
- Optimistic update, stale edit protection, soft deletion and restore
- Encrypted database restart and independent vault isolation
- Invalid amount, title and calendar date rejected before persistence
- Freeze blocks writes until migration snapshot releases its lease

## Still blocking production cutover

This is not a production app integration. Before the live app may use it:

1. Extend typed commands to every financial entity and approved restore behavior:
   categories, saving goals, recurring, challenges, receipts and SMS dedupe.
2. Implement one **atomic encrypted SQL transaction** for ledger mutation plus
   cloud outbox enqueue; durable idempotency for SMS and recurring jobs.
3. Route every UI and background code path through the gate/repository,
   including screen edits, notifications, widgets, import and exports.
4. Complete key backup/recovery on mobile devices and safe upgrade/rollback;
   block silently migrating or deleting any legacy preferences.
5. Run release APK tests and explicit user-device validation; preserve
   Arabic/English reports and financial analytics consistency.

Do not merge stacked draft branches to `main` or activate a migration until
the above gates, encryption/recovery policy and final build pass. Firebase
project owner authorization remains a later separate requirement.
