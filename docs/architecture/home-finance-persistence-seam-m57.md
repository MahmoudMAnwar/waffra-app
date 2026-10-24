# M57 — first live HomeScreen finance persistence seam (NOT SQLCipher activation)

## What is connected in the running app

HomeScreen now uses `WaffraHomeFinancePersistence.loadLegacy()` for its
finance read view and `saveLegacy()` for its queued finance batch saves.
This is an actual app integration, rather than another isolated repository
prototype. All pre-existing screen JSON fields, categories, goals, recurring
records, challenge/trash records, SMS hashes and non-finance preferences
retain their existing behavior.

The bridge requires a valid legacy source, replays pending widget commits
under the existing cross-engine writer coordinator, checks both raw ledger
and widget revision on saves, and refuses unexpected preference keys. A
pending or active encrypted cutover marker blocks legacy reads and writes.

## Explicit non-goals

- No migration of user data, source marker write, SQLCipher vault selection,
  Firebase/Firestore sync, receipt installation, APK deployment or merge.
- It does NOT make SharedPreferences' multi-key saves atomic, nor replace
  the current widget SMS writer or other direct legacy write paths.
- No user-visible behavior or design changes are intended.
- The M56 encrypted vault recovery protections remain unchanged.

## Validation and following milestone

New tests cover screen reads, preservation of non-finance settings and
untouched SMS hashes, multi-field writes, widget-revision conflicts, fail-closed
cutover markers, and invalid save payloads.

Before switching the actual source, the app AND quick-add widget must route
every relevant read and mutation through the same durable selector and
cross-process writer gate; preserve receipt bytes and all auxiliary finance
keys; implement verified, crash-safe activation/rollback and run real Android
cold-start, UI, PDF, SMS, recurring and widget parity tests. Firebase sync stays
disabled until local storage is stable.
