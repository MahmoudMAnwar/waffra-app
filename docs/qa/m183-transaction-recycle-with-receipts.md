# M183 — reversible SQLCipher transaction + receipt recycle (release NO-GO)

## Implemented candidate

`WaffraEncryptedTransactionRecycle` adds a *separate* transaction-level
encrypted trash mechanism. Unlike the existing M117 receipt-only recycle, it
can remove the **financial transaction itself**, while archiving all of its
already-encrypted SQLCipher receipt BLOBs under the same native Home/Widget
writer lock.

Deleting requires an explicit confirmed user intent; an immutable original
snapshot revision + digest; and the **individual SHA-256 fingerprints of every
displayed receipt**, because an image may be replaced without incrementing
finance generation. Under a single SQLCipher transaction it verifies complete
normalized ledger and JSON parity, validates no receipt-only archive or
legacy receipt representation is left behind, archives source JSON with a
SHA-256 checksum and copied BLOBs, deletes old SQL owners/receipts and commits
the reduced canonical finance snapshot. Any failure rolls everything back.

Restore also holds the source lock and a single SQL transaction, rejects stale
revision, duplicated transaction ID, malformed transaction JSON, modified
money checksum, modified/missing image bytes, invalid receipt ownership,
rolled-back clock and expired 30-day recovery. On success it restores the
original JSON financial row, exact receipt bytes and typed SQLite row, and
consumes the trash item within the same transaction.

The existing bank SMS SHA-256 fingerprints intentionally remain untouched.
The engine never emits temporary plaintext files or places backups on the
clipboard. Archived BLOBs are encrypted **at rest by SQLCipher**, and stored
only in that database.

## Synthetic test coverage

`test/storage/m183_encrypted_transaction_recycle_test.dart` checks
receipt-backed deletion, full byte-exact undo, deletion without attachments,
concurrent Widget/financial revision change, in-place receipt replacement,
missing confirmation or receipt witnesses, expiry and clock rollback,
archive BLOB corruption, archived money tampering, pending source marker
rejection and disabled-by-default behavior.

These are disposable, synthetic SQLCipher tests; their injected witness is NOT
OS-backed key attestation or real-device testing.

## NOT YET CONNECTED / unsafe to release

This standalone transaction recycle writer is deliberately **not installed in
HomeScreen/Widget**. Production source still uses guarded legacy. Until
screen-specific deletion/undo UI captures receipt byte witnesses and an
independent verified authority calls this port, do not advertise live
transaction deletion under SQLCipher. Other unverified routes remain:
category/goal/recurring trash+purge; source-backed encrypted backup restore;
full reset, startup and Widget balance, physical Android key recovery, 2-phone
restore and receipts.

**Permanent expiry purge of archived bytes** requires a separate monotonic
clock/recovery contract; current API rejects undo after 30 days but retains
encrypted tombstones. This prevents accidental loss during development but is
not the eventual 30-day deletion retention guarantee.

No production activation markers, key material, actual user transactions,
Firebase configuration or Google Play release are modified.
