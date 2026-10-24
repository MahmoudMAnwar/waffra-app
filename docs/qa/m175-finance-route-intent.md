# M175 — tag live mutation routes separately (fail-closed)

## Why this matters
HomeScreen previously supplied `WaffraFinanceRoute.transactionEdit` for
almost all `persist()` operations, including adding a manual transaction,
deleting/undoing a transaction, and posting/postponing a recurring transaction.
A future SQLCipher cutover must independently prove each of the 24 routes.
Tagging every action as an editor would wrongly hide unsupported SQL mutations.

## M175 change
- `persist(route:...)` now carries an explicit intent through the existing
  `WaffraVerifiedFinanceAuthority.saveCaptured` and source guard.
- Fresh manual saves and edits distinguish `manualTransactionSave` from
  `transactionEdit`.
- Both deletion and undo tag `transactionDeleteAndUndo`.
- Both recurring payment posting and postponement tag
  `recurringPostingAndPostponement`.
- No default storage flag, SQL writer, key, activation marker, Firebase service,
  migration, receipt bytes, or existing guarded-legacy persistence format
  is changed.

The current guarded legacy writer still functions through the same
cross-engine writer and journal. Unsupported encrypted manual/delete/recurring
routes intentionally reject inside `saveCaptured` until an independently
validated atomic SQLCipher implementation exists.

## Remaining work — still production NO-GO
1. Replace generic snapshot writes with independently verified atomic SQL
   operations for manual creation, deletion/undo, recurring and category/goal
   mutators, each under common Widget/Home locking and recovery rules.
2. Audit and tag the remaining categories, goals, trash, challenges, budgets,
   receipts, restore and reset finance routes; 24/24 live routes need proof.
3. Real device migration and crash recovery, nonempty backups, encrypted
   receipt lifecycle, two-physical-device restore, signed Android and public
   privacy/account deletion requirements remain independent release blockers.

M175's successful CI is **not** permission to enable SQLCipher production.
