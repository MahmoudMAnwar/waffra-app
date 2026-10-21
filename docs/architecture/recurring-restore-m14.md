# M14 — Recurring schedule restore requires new due date

The encrypted **experimental** repository for recurring bills is separate
from the current SharedPreferences scheduler.

## Guarantees and tests

- Seeds a stable working copy from verified relational recurring rows, both
  active and previously deleted, preserving original source JSON.
- Deletion is soft and deactivates only the working schedule, with a timestamp
  and optimistic expected version. Previously generated ledger entries are
  not removed or changed.
- Restore is available within 30 days and **requires a new future calendar
  date** chosen by the user. Reject missing, impossible and past dates.
- Restoring marks the schedule active, changes its next due date and due-day,
  but **does not immediately generate any financial entry**. Future scheduler
  integration must deduplicate using existing `rec_...` transaction IDs.
- Repeated seeding, duplicate restores and cross-vault edits fail closed.
- Tests prove historical recurring-generated transactions are unchanged,
  independent vaults remain isolated and expired deletes cannot be restored.

## Production cutover blockers

- The app-wide recurring engine, reminders, widget, receipts, PDFs and SMS
  integration are **not connected** to this prototype.
- Schedule generation and postpone/resume logic must be implemented atomically
  with ledger and outbox using stable historical IDs. Verify timezone and
  DST boundaries using the selected user's local calendar.
- Account switching, backups, safe rollback, encrypted storage on both mobile
  platforms, 30-day deletion policy and UI confirmation remain release gates.
- Firebase provisioning, staging emulator tests, E2EE key recovery approval,
  conflict resolution and legal/privacy sign-off are also outstanding.

No startup hook, data migration, backend writes or production sync is enabled.
Keep this and all dependent pull requests in Draft until full device testing.
