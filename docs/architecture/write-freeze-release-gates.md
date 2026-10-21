# Storage M9 — cooperative financial write-freeze (draft, inactive)

**Depends on draft PR #11. No app integration or user migration.**

## Purpose

Before importing historical transactions from SharedPreferences into the new
encrypted SQLite vault, capture a stable snapshot. Otherwise an in-flight
widget, bulk pasted SMS, recurring task or UI save could update the source
while it is being copied, creating mismatched totals or lost records.

`WaffraFinancialWriteGate` provides an isolated, tested cooperative protocol:

- Every ledger mutation MUST enter via `runWrite`, including asynchronous
  jobs, home widgets and non-UI writers. It tracks writers already in progress.
- `freeze()` immediately stops admitting new guarded writes, drains all
  in-flight writes, then yields a lease. Callers snapshot and verify only
  AFTER awaiting that lease.
- The migration caller MUST release the lease in a `finally` block regardless
  of SQLite integrity/validation error. It is safe to release a lease twice.
- Re-entrant freezes and nested guarded writes fail closed, avoiding a deadlock
  if migration starts during a nested operation.
- After release, queued writes recheck gate state before entering; a different
  migration can acquire a new freeze while tasks are waiting.

Example for a FUTURE coordinated migration (not wired into production):

```dart
final gate = WaffraFinancialWriteGate();
WaffraWriteFreeze? lease;
final coordinator = WaffraMigrationCoordinator(
  openEncryptedStore: openVerifiedEncryptedVault,
  acquireWriteBarrier: () async { lease = await gate.freeze(); },
  releaseWriteBarrier: () async {
    lease?.release();
    lease = null;
  },
);

// Only AFTER all UI/SMS/recurring/widget writes go through runWrite():
// await coordinator.stageWithBarrier(vaultId: activeVaultId);
```

This does NOT make database writes atomic. The actual future repository must
write both the financial change and its encrypted cloud outbox entry within
ONE SQLite transaction. The gate is not a mutex for competing UI updates.

## Blocking before cutover

1. Route ALL financial writers through the same process-wide gate; audit
   every SharedPreferences writer and any isolate/platform callback.
2. Handle operations running in other processes/isolates; a Dart gate alone
   is not cross-process.
3. Flush widget/background work and pending preferences commits before freeze.
4. Ensure synchronous cache updates do not make ledger data appear saved before
   durable persistence, and that long-running writers cannot hold the barrier
   forever.
5. Add a crash-aware cutover journal, encrypted backup and recovery UI.
6. Verify parity and original receipts, and exercise failure/restore and
   app upgrade on real Android and iOS devices.
7. Preserve the legacy source until a verified production cutover; no
   automatic cloud upload merely because Google login is active.

The feature is intentionally NOT connected to the live `main.dart` and does
not switch databases, delete preferences, or enable Firestore.
