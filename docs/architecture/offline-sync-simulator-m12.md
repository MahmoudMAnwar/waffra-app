# Storage M12 — offline remote transaction replay simulator

**Current state: all network access is absent. No Firebase connection or
user-data upload. This is an in-memory simulation contract for future work.**

## Local transaction replay contract

- The future `WaffraAtomicCreatePort` must atomically read remote state and
  create an encrypted document ONLY when none exists. If the exact mutation
  already exists, it returns the exact receipt. A different remote revision
  must be reported as a conflict, not overwritten.
- An unverified or lost remote result must **never** acknowledge/drop the
  SQLite outbox entry. On retry, the same mutation ID and encrypted bytes
  must be reused; do not re-encrypt and lose idempotency.
- A complete set of consent/account/key recovery/rules/region/atomic port
  gates must be supplied. The coordinator itself is disabled by default.
- Each vault is handled independently. Deletes are encrypted tombstones.
- Tests simulate successful create, a dropped response after remote commit,
  stale concurrent edits, fake/malformed receipts, blocked consent, multi-vault
  separation and tombstone preservation.

## Critical omissions blocking real Firebase sync

1. This simulator has **no real implementation of Firestore transactions**.
   Do not equate a fake passing test with deployed security, transactional
   consistency or server acknowledgement.
2. Real updates to an existing financial document are deliberately blocked.
   Implement an audited compare-and-swap parent revision chain and conflict UI
   before attempting update, merge or delete. A create-only port alone cannot
   serve live recurring financial edits.
3. The current `firestore.rules` must be evaluated and strengthened for
   concurrency, tombstones, key-recovery metadata and per-device revocation;
   run the full Firebase Emulator suite and staging deployment under user
   ownership before production.
4. A correct adapter must enforce real Firebase Auth UID/vault binding, know
   the approved staging/project/database/region, and avoid privileged server
   bypass or permissive wildcard rules.
5. Implement encrypted local-ledger transaction + outbox enqueue atomically,
   crash-safe remote cursor and already-acknowledged replay journal.
6. Live mobile activation requires explicit opt-in, E2EE key recovery,
   30-day recoverable category/goal behavior, backup/restore, PDPL assessment,
   performance/privacy QA and a controlled release rollout.

The `WaffraSyncDryRunCoordinator` is NOT called from `main.dart`; it should
only receive an in-memory fake port in tests. PR is Draft, stacked on M11.
