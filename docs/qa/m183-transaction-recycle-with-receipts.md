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
clipboard. The verified authority refuses this new transaction-recycle API
when the selected finance backend is guarded legacy. Archived BLOBs are encrypted **at rest by SQLCipher**, and stored
only in that database.

## Synthetic test coverage

`test/storage/m183_encrypted_transaction_recycle_test.dart` checks
receipt-backed deletion, full byte-exact undo, the verified Authority/Session/
Bridge round trip, deletion without attachments,
concurrent Widget/financial revision change, in-place receipt replacement,
missing confirmation or receipt witnesses, expiry and clock rollback,
archive BLOB corruption, archived money tampering, pending source marker
rejection and disabled-by-default behavior.

These are disposable, synthetic SQLCipher tests; their injected witness is NOT
OS-backed key attestation or real-device testing.

## Conditionally wired to Home, still unsafe to release

The transaction recycle writer has an explicit verified Authority →
Encrypted Session → Encrypted Bridge path. This change also adds the
**conditional verified SQLCipher HomeScreen branch**: before consent it
compares the selected rendered transaction against its exact current
financial ledger row, captures the independent receipt-screen generation
and all image SHA-256 witnesses, and then submits the confirmed delete
through the finance write queue. Only after the verified authority reopens
the committed source does Home update its ledger, amounts and Widget
revision. Undo follows the same queue with a fresh source read.

The transactions menu also offers an encrypted Recently Deleted (30 days)
dialog, whose metadata comes from SQLCipher and whose recover action calls
the same verified authority. The existing guarded-legacy delete and
six-second Undo path is unchanged. Unit tests cover stale selected rows,
receipt-reference modifications, duplicate IDs, malformed finance and
unrelated Widget inserts.

**This is staged code, NOT active production storage.** The running Home
still constructs a legacy-only authority by default; it cannot select
SQLCipher until independent real-device source witnesses are approved.
This screen conditional is NOT proof that any of the 24 live routes are
certified. Other routes still needing work include category/goal/recurring
trash and permanent purge; verified active-source backup restore; full
reset, startup, real Widget balance and cross-device key recovery.

**Permanent expiry purge of archived bytes** requires a separate monotonic
clock/recovery contract; current API rejects undo after 30 days but retains
encrypted tombstones. This prevents accidental loss during development but is
not the eventual 30-day deletion retention guarantee.

No production activation markers, key material, actual user transactions,
Firebase configuration or Google Play release are modified.
