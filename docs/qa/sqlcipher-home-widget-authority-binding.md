# SQLCipher authority wiring — Home and Widget (production NO-GO)

This integration connects **both real Flutter engines** to a shared startup
authority binder. The app has not switched production storage.

## Code path

- Home `_ensureFinanceBound()` runs before its first financial read. It keeps
  the bound authority and closes any open encrypted store on dispose.
- The separate widget engine binds its own source at startup and reuses the
  same verified authority for read and confirmed SMS writes.
- A verified guarded-legacy source continues to use the existing
  cross-engine legacy journal and writer lock.
- If an encrypted active marker exists, `bind` requires independently
  certified production release evidence before reading *an existing* vault.
  It opens SQLCipher with the stored OS key, initializes no new vault or key,
  constructs the encrypted snapshot/journal/bridge/session, and performs a
  real encrypted startup read that rechecks dual activation witnesses under
  the cross-engine lock. Failures close the store and block both engines.
- A missing/invalid source, missing certified evidence, invalid source
  transition, wrong key or missing vault never falls back to legacy or
  substitutes a zero balance.
- The current shipping UI provides **no certified release evidence**. This
  means that the new binding is real code, but an activated SQLCipher source
  remains blocked until all independent conditions are implemented and proven.

## Remaining independent work (release-blocking)

1. Device-backed attestation and persisted verified evidence, not synthetic
   boolean flags; real 24/24 route instrumentation, with receipt lifecycle.
2. Legacy migration, external/SQL checkpoints, source selector transition and
   crash-consistent rollback against non-empty finance and invoice fixtures.
3. Android home widget cold restart/cross-process locks, signed build, two
   physical Android phones and authenticated cross-device recovery.
4. Account deletion, encrypted backup swap, data-safety/public privacy links,
   logging and Crashlytics policy approval, and explicit release authorization.

CI uses a strict five-lineage scope audit and full Flutter/ARM64/security
regressions. Passing CI does **not** authorize cutover or Play publishing.
`automaticallyActivateSqlCipher` remains `false`.
