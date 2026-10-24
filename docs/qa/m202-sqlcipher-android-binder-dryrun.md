# M202 — SQLCipher authority binder on a real Android emulator (NO-GO)

Status: **EXPERIMENTAL / PRODUCTION NO-GO**. This is a focused runtime
test of the already-existing source binding, not a new user feature.

The current signed app intentionally has no automatic SQLCipher activation.
The existing release gate must remain `automaticallyActivateSqlCipher=false`.
Only isolated synthetic test keys and data are permitted in this suite.

## What the Android emulator actually runs

1. Bootstrap a throwaway SQLCipher file under Android's temporary app storage.
2. Commit a valid empty encrypted finance snapshot and both cutover witnesses
   in this isolated test fixture. The `_DisposableActiveSource` and green
   `WaffraProductionCutoverEvidence` exist **only inside this test file**.
3. Invoke the **actual shipped** `WaffraProductionFinanceAuthorityBinding.bind`
   for the widget startup route and independently reopen this durable vault.
4. Save an explicitly confirmed expense through the **actual**
   `WaffraVerifiedFinanceAuthority.commitConfirmedSms` using the widget
   transaction route. Verify exact minor units and stable entry ID.
5. Close the widget binding; instantiate the Home startup binding using
   the same pre-existing encrypted database and verify the same persisted
   finance ledger and verified SQL-backed authority.
6. Attempt to open with a wrong encryption key; require rejection without
   silently returning legacy/zero and without changing file size.
7. Reopen with the correct key, verify the same finance data, ensure the
   SQLite header is not plaintext, and verify the test's legacy preferences
   were not changed.
8. Re-run the already-existing Android tests for nonempty legacy migration,
   receipt-integrity verification, encrypted receipt cold reopen and
   authenticated portable restore using disposable images and data.

Run in `.github/workflows/m202-android-sqlcipher-source-binder-dryrun.yml`
using `reactivecircus/android-emulator-runner` and the fail-fast script
`.github/scripts/run-m202-sqlcipher-binder-android.sh`.

The workflow must fail on **any** test error or timeout and must report
whether Android execution really succeeded, not merely Dart analysis.

## What this deliberately DOES NOT prove

- No actual independently running Android **Widget engine**, Flutter UI
  tap flow, biometric consent or release-signed customer APK was exercised.
  The widget startup/confirmation **route and real session factory** are
  exercised from the Android integration-test process.
- No real OS-backed user key is generated or read: the Android key reader is
  replaced by a test-only injection.
- No physical phones or two-phone backup recovery are available in CI.
- No actual user storage, account or Firebase data are migrated.
- It does not independently attest all **24 live finance routes**. Those are
  still release blockers, as recorded in the M201 matrix.
- Passing cannot create source activation markers, bypass the approval gate,
  set production cutover flags or justify publishing to Google Play.

Do not count synthetic green approval booleans as evidence that the
independent real-device release prerequisites passed.

## Subsequent required human/device evidence

Two real Android handsets with one verified signed build must demonstrate
independent app/widget startup and concurrent writers, encrypted OS-key
recovery, 24 route-specific witnessed app actions, migration and rollback
from nonempty ledger and receipt attachments, portable backup with exact
receipts verified after reinstallation on a second handset, and fail-closed
crash/restart. A tester should record redacted source witness and digest
before any explicit production release approval.

Google Play is the **last** stage.
