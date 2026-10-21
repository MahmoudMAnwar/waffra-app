# Storage M8 — encrypted offline cloud replay queue (draft, not active)

**Status:** Local-only proof-of-concept. No Firebase connection, backend
provisioning, sync permission, background task, UI hook, or production cutover.
Depends on draft PR #9 (AES-256-GCM encrypted cloud record envelopes), PR #8
(candidate restrictive Firestore rules), and the existing encrypted SQLite
prototype. The normal Waffra app remains on its current local data store.

## Implemented

- `lib/storage/waffra_sync_outbox.dart` stores **ciphertext-only** records in
  the *encrypted* local SQLite store and loads them after a process restart.
  No raw bank SMS, account details, receipt file paths, transaction titles or
  plaintext amounts are queued.
- `enqueue` is idempotent for exact same encrypted mutation bytes/nonce and
  fails closed if an existing mutation ID is reused with different contents.
  Versions must strictly increase for outstanding changes to one record.
- Cloud document IDs use SHA-256 over JSON `[kind, recordId]`: category and
  entry with the same source ID map to different Firestore document IDs.
- `pending(vaultId)` scopes the queue to one vault and schedules **at most one**
  mutation per record; follow-up changes wait for acknowledgement.
- `preflight` blocks unless explicit sync consent, verified identity,
  recovery readiness and transaction-capable remote transport are all true.
  A confirmed absent document is a candidate for atomic create-only; exact
  matching remote mutation is safe to acknowledge; any different existing
  revision is a manual conflict — **never last-write-wins**.
- `acknowledge` removes a local queue entry only when the supplied remote
  revision exactly matches identity, version, mutation, device and deletion flag.
  Deletions are encrypted tombstone writes, not automatic remote deletes.
- Tests exercise restart persistence, ciphertext-at-rest, vault isolation,
  retries, FIFO, competing devices, consent gates and deletion tombstones.

## What this DOES NOT establish

**There is still no implementation capable of writing or reading Firestore.**
Local preflight is not a substitute for **Firestore transaction-based compare
and set**: server contents can change between a query and a write. The adapter
must rerun these checks atomically on remote state, and must not allow naive
`set()` overwrites. Existing draft rules alone cannot guarantee prevention
of equal-version collisions, deleted-vault races or changes from other devices.

The prototype uses the shadow encrypted SQLite DB, **not** an integrated
production ledger transaction. Before enabling actual sync, implement:
1. A single durable ledger/outbox transaction with a real write barrier covering
   UI, SMS bulk import, recurring tasks and widgets; no dual writes by default.
2. Per-vault signed-in account binding with explicit ownership confirmation.
3. E2EE key wrapping/recovery across phones, lost device handling, rotation,
   and deletion of keys when revoking sync. A login alone is insufficient.
4. Firestore project owner connection, verified Saudi-region database setup,
   real rules/emulator tests and billing / PDPL review.
5. Transactional adapter with server-side idempotency and version checks.
   Sync deletion, conflict inspection and quarantine/recovery UI are required;
   do not silently drop a remote or pending local edit.
6. Durable acknowledgement/progress cursor, crash-safe retries and offline
   reconciliation. The acknowledged mutation must remain protected from replay
   duplication after it leaves the local outbox.
7. Android/iOS device and upgrade/downgrade testing, real-account isolation,
   export / restore, load testing and explicit release approval.

**Safety:** Do not merge these stacked draft branches into main, enable a
financial sync feature flag or deploy the candidate rules until all release
gates are satisfied. The current user financial history remains untouched.
