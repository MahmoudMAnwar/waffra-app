# M39 — fail-closed offline finance source selection (policy prototype)

A successful fresh-install SQLite experiment is not a safe live migration unless every launch knows which datastore is authoritative.

This pure policy deliberately distinguishes:

- Truly new device with no finance storage and no active writer: **fresh candidate**, not automatically activated
- Device containing any old finance preference key (even an empty entries array): **legacy source**
- **Encrypted active** only when an external preferences pointer AND an independently verified encrypted SQL activation marker both exist, the encrypted file/key are usable, and the current binary understands the encrypted repository
- **Recovery required** for interrupted cutover, activation pointer without DB, DB without activation pointer, missing encryption key, malformed marker or trying to run an old app binary after activation

The policy never erases existing finance preferences or creates a fresh vault when the evidence is contradictory. Old preferences may remain read-only for recovery once encrypted storage becomes authoritative.

## Not yet safe to ship

This module only determines a source status from independently collected evidence; it does NOT write activation markers, freeze all current main/widget writers, authenticate a database row, implement backup or route HomeScreen reads/writes. Both markers must be written with a recoverable multi-step journal and replay logic under a writer lock; the SQLite SQL marker must be independently verified on app startup. Missing key/data scenarios need a user-visible recover/reinstall path, never a silent empty vault.

The Android widget can launch a separate Flutter engine. It must use exactly the same source selector, encrypted vault and writer lock once the cutover is active.

No Firebase involvement is required. Do not merge this work as a production source switch.
