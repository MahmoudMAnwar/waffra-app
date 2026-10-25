# M211 — Native Home/Widget lease for lossless SQLCipher staging

**Status: Staging-only / production NO-GO.** The user asked to place all
financial Waffra data in SQLCipher. This milestone upgrades the migration
capture path, but does **not** change where the running app persists money.

## What is implemented

- `WaffraMigrationCoordinator.stageWithSharedWriterLease` uses the actual
  `WaffraLegacyFinanceWriterCoordinator.withCurrentPreferences` boundary:
  the same cross-engine native lock as Home/Widget confirmed SMS writes.
- The lock rechecks the active/pending source markers and encrypted source
  evidence, reloads the native preferences and recovers both interrupted
  legacy transaction journals before a frozen copy is taken.
- Copy only registered financial preference keys (transaction ledger,
  categories, goals, recurring bills, budgets, challenges, deleted entities,
  dedup hashes and financial settings); never copy UI theme/language by
  accident. Deep-copy mutable lists and make the map immutable.
- Hold the lock **through** encrypted SQLCipher import, normalized projection
  and checksum/count/income/expense/receipt-reference parity verification.
  Always close the database and release the lock on error; do not mutate
  legacy balances or upload a backup to a cloud provider.
- Native-lock Flutter tests stage a historical synthetic multi-line bank SMS,
  reopen the SQLCipher relational projection, and confirm old preferences
  stayed unchanged. An active source marker blocks the stage before the
  vault is opened. Unit test callbacks are isolated from the actual
  cross-engine lock method.

## Still required for all-finance SQLCipher activation

Staging a candidate is **not activation**. An independent production
coordinator must collect real source and hardware witnesses, encrypt
legacy **receipts' image bytes** (not merely their paths), validate all **24**
live finance routes and OS key recovery, perform a crash-safe two-witness
cutover, test signed builds and encrypted portable backups on **two physical**
Android phones, and obtain an explicit release GO before switching source.

Do not create/delete any real vault or source marker in this milestone.
The old SharedPreferences writer stays active; the SQLCipher candidate
is non-authoritative, has no automatic switch, and the legacy SMS-original
privacy guard continues to reject plaintext notes.

## Known remaining data migration gap

The legacy preflight financial-key inventory does not include the separately
stored `waffra_custom_goals_v1` suggestions. They must be imported to the
verified encrypted custom-goals table, or explicitly approved as excluded,
**before** claiming all local finance-related data has been migrated.
The M211 migration test now asserts immutability of an actual registered
finance string-list key (`waffra_sms_hashes_v1`), not this missing key.
This gap is NOT waived by success in staging tests.
