# M188 — Full encrypted finance reset: synthetic atomic candidate, NO-GO

## Implemented and tested

`WaffraEncryptedFullFinanceReset` is a standalone, **default-disabled**
SQLCipher writer with no Home/Widget or production authority callsite.
It differs from deleting one transaction or emptying only the dashboard.

Before deleting anything it requires:
1. An immutable finance generation + digest and independently selected encrypted
   source, verified again inside the same native Home/Widget file lock.
2. Explicit irreversible user confirmation, matching confirmation phrase,
   independently OS-attested biometric proof **not available in this
   candidate**, and acknowledgement that an encrypted backup was separately
   saved (caller boolean is **not** an actual export or device attestation).
3. A current, password-authenticated portable Waffra V2 backup of all active
   finance keys, financial ledger and byte-exact invoice attachments. Restore
   integrity is checked **against the active source**, including every amount,
   category, date, receipt reference, SMS-dedupe SHA and independently typed
   custom goal suggestion.
4. No unbacked recoverable trash records, deleted category/goal/recurring
   archives, dangling/legacy receipts, unknown future financial SQL tables or
   independent typed settings without an authenticated backup projection.
5. Strict current SQL-money typed amounts, income/expense flags, identity,
   dates, receipt counts, module typed projection, byte-level receipts and SMS
   hash parity; any discrepancy fails without partial writes.

With all checks satisfied, and **only under a single SQLCipher transaction**,
it erases the known active finance typed tables including transactions, invoice
BLOBs, category/goal/recurring entities, saved custom goals, SMS deduplication
hashes, and financial settings, then commits a fresh canonical empty ledger
snapshot with a **higher generation**. The verified SQLCipher source and
existing OS key remain; switching source pointers, deleting an account, cloud
data or external backup are not part of this finance-only operation.
All relevant typed tables are verified empty before the transaction returns.
Any validation or SQLite failure rolls the entire operation back.

The data in 30-day recoverable trash is **NOT** automatically purged by reset:
the reset is explicitly rejected while any such data exists, because the
portable V2 backup format does not yet include those tombstones. First provide
a separately approved recovery/retention plan.

## Disposable tests

`test/storage/m188_encrypted_full_finance_reset_test.dart` seeds
a nonempty SQLCipher transaction with an encrypted invoice and SMS hash.
Tests check exact authenticated reset + cold reopen, non-finance locale
preservation, wrong password, missing confirmation/biometric/backup proof,
stale Widget source, failed source witness, typed monetary manipulation,
invoice count tampering, SMS SHA corruption, retained 30-day trash and
unknown future finance tables. All data are synthetic disposable fixtures.

## Explicit blockers

- `biometricVerified` and `externalBackupSaved` booleans in this
  isolated prototype are NOT security proofs. Production needs true
  platform-biometric attestation and independently verified receipt of the
  user's saved encrypted archive.
- Current typed financial settings with unverified backup parity must be
  supported before a real user's populated vault can be reset.
- The existing guarded legacy app cannot invoke this writer; no production
  source selector, Widget, or cloud account deletion is changed.
- Deleted-entity/transaction retention export, full key erasure and verified
  account deletion require separately authorized user workflows.
- 24/24 production financial routes, OS key recovery on actual devices,
  two physical phones and cross-device restore, signed Android release,
  privacy/Data Safety/Crashlytics, and human release approval are pending.

**State: M188_ATOMIC_FULL_FINANCE_RESET_CANDIDATE_NO_GO.**
