# M22 — append-only, disposable restore checkpoint journal

This experimental component records the three independently verified rehearsal phases: authenticated encrypted archive, audited receipt bytes, and encrypted ledger parity. It is disabled by default and *never* touches a live file or database.

## Properties
- Journal contents are metadata only: 64-character source checksum, entry count, receipt count, phase number, phase name, digest and predecessor digest. No transaction descriptions, account identifiers, attachment paths, password or receipt bytes.
- Every phase is a new append-only file in a caller-provided **disposable, real** directory. Previous checkpoint files are not rewritten.
- Writes are flushed to a `.pending` file and renamed after creation. On restart, a leftover `.pending` file or an unexpected checkpoint fails closed. No automatic forward resume or cutover.
- A digest chain detects accidental corruption and inconsistent source changes across the journal. **Hashes do not authenticate against a malicious local writer.** Do not interpret them as a signature, user consent, or permission to replace data.
- Out-of-order transitions, duplicate phases, changed record counts, and symlinked journal directories are refused.

## Critical limits
A successful M22 journal must NOT be used as evidence that restoration of real devices is safe. The caller remains responsible for verifying each phase using M21; journal writes don't perform or repeat that verification. The caller must use an isolated single-writer disposable directory. Atomic filesystem/SQLite installation, real-device crash rollback, disk-full recovery, cancellation, and explicit user approval remain mandatory before any live migration.

Continue without Firebase. Keep these stacked draft PRs unmerged pending full Android test and production cutover review.
