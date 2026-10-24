# M184 — atomic SQLCipher transaction/receipt expiry purge (synthetic only)

## What is implemented

`WaffraEncryptedTransactionRecycle.purgeExpired` is a new **explicit,
default-disabled** SQLCipher-only deletion candidate. It cannot be invoked
through the live Home, Widget or finance Authority. It requires a caller-owned
`verifyIndependentClockUnderLock` function, intended to authenticate two
**independent**, protected UTC clock sources. The core takes the *earlier*
timestamp and refuses skew greater than two minutes, negative timestamps and
an older value than its previously persisted SQLCipher clock watermark.

While holding the same Home/Widget native writer lock and one SQL transaction,
the candidate checks current finance snapshot integrity and complete typed
active-ledger parity. It refuses malformed archive metadata, unknown owners,
an active transaction with the same ID, archived financial JSON/SHA mismatch,
receipt-reference count mismatch, missing BLOBs, incorrect immutable
owner-derived filenames, corrupted invoice SHA-256/length or an independent
receipt archive.

After **all** selected expired rows and receipts validate, the candidate
deletes at most two archived records and their encrypted invoice BLOBs per
call, commits its durable lower-bound UTC clock watermark and verifies that
no canonical transaction, balance, SMS-hash history or finance generation
changed. A failed check rolls back every deletion and the clock update.
Already-purged rows never trigger a second financial deletion.

## Critical release limitations

Synthetic Flutter regression tests inject two artificial clock values.
**Those are not OS attestation, signed network time or real-device proof.**
No production caller or platform-independent trusted deletion-time clock
attestor currently exists. The M183 deletion UX captures device wall time,
not an independently authenticated deletion timestamp. **This means M184
must not be enabled for users until the original deletion-time witness is
durably authenticated as well as the future expiry time**: a manually
backdated clock must never shorten the required 30 days.

The new API is deliberately neither called by default nor added to a live
scheduled background purge task. It doesn't access filesystem receipts,
clipboard, SharedPreferences source markers, Firebase or Google Play.

## Synthetic negative tests

The M184 tests in `test/storage/m183_encrypted_transaction_recycle_test.dart`
exercise 29d/23h retention, exact 30d expiry, receipt-free expiry, no-op
idempotence, two independent clock mismatch, stored SQLCipher UTC watermark
rollback, corrupted archived invoice bytes, altered archived money, unavailable
second time attestor, pending source marker, invalid batch and default-disabled
SQLCipher paths.

## Remaining independent release blockers

- Trusted deletion-time witness on real Android devices, offline/reboot
  rollback recovery and final TTL policy approval
- 24/24 verified live routes; active-source backup restore/full reset
- Category/goal/recurring recycle, secure permanent purge and receipt parity
- Real Home/Widget encrypted source, OS-backed recovery, 2 physical phone tests
- Signed Android delivery, AR/EN policy/delete-account URL, Data Safety,
  Crashlytics consent and explicit human production GO/NO-GO

**Status: synthetic retention engine candidate only. Production NO-GO.**
