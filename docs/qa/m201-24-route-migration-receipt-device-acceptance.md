# M201 — SQLCipher route, migration, receipt, restore and device acceptance

**Production status: NO-GO.** This is QA for the existing Waffra
implementation; it adds no user-facing feature, new bank integration, or
Google Play deployment. The CI tests below use **synthetic disposable data**.

## Evidence levels that must not be confused

1. **Route inventory (24/24 defined)** proves only that the API tracks all
   required routes; it does not prove the code executed on a real phone.
2. **Contract/fail-closed tests** prove missing key/receipt/restore/witness
   evidence blocks encrypted selection for every route. They do not establish
   the presence of authenticated evidence.
3. **SQLCipher integration tests** exercise non-empty legacy migration,
   typed ledger CAS, receipt hashes, delete/undo, encrypted portable
   backup/restore and full finance reset in throwaway vaults. They do not
   certify the real end-to-end Android Home/Widget user journey.
4. **Real hardware acceptance** requires two physical Android phones with
   the same reviewed signed APK and independently collected evidence for
   each live operation, restart, crash, receipt and source-backed restore.
   CI Android emulators or mock ADB cannot substitute for these proofs.

The exact-SHA CI workflow is
`.github/workflows/m201-sqlcipher-finance-acceptance.yml`.
Its exported JSON always reports **zero verified live route witnesses** and
**zero attested physical phones**, even when all unit tests pass.

## Prepare two real handsets (explicit operator action)

Do this on a workstation with two authorized Android phones. Use **only
synthetic finances**, a disposable test account, and a reviewed signed APK.
Never export messages, credentials, real balances, image bytes or OS keys to
GitHub CI.

1. Check the exact `main` commit, the app signing certificate matching the
   Firebase-registered release certificate, the package
   `com.waffra.app`, and the downloaded APK SHA-256. Both phones must run
   exactly that verified signed APK. Do not use a debug build as a
   production-signature witness.
2. Install the reviewed APK on both phones by authorized device tooling.
   Check `adb devices -l` displays **two distinct physical** online devices.
3. Capture the **read-only hardware-only** evidence locally:
   `python3 scripts/qa/m189_physical_device_source_probe.py --capture --output /private/evidence/m189-devices.json`.
   An emulator or a missing app is rejected. The report is private and
   intentionally says `PHYSICAL_HARDWARE_DETECTED_ONLY_RELEASE_NO_GO`.
4. Test the existing Android instrumentation on *both* authorized devices
   with a disposable encrypted finance dataset, using supported
   `flutter test integration_test/<test-file>.dart -d <device-id>`
   commands where test prerequisites and package signing permit it. The
   currently available suites include
   `integration_test/live_finance_migration_receipts_android_test.dart`,
   `integration_test/m120_verified_receipt_reopen_android_test.dart`,
   `integration_test/finance_release_regressions_android_test.dart`,
   `integration_test/offline_restore_android_test.dart`, and
   `integration_test/verified_encrypted_finance_bridge_android_test.dart`.
   Unit test success does not imply these executed on the two phones.
5. Inspect each in-app operation independently on the **actual activated
   source** (after separate, explicitly authorized production-gate review):
   account/login → Home cold read → stand-alone Widget cold read → 100 SMS
   paste and confirmed append → edit → delete/undo → encrypted invoice
   attach/view/reopen/remove/restore → categories/goals/recurring budgets
   and recycle → export → authenticated restore on phone B → close/relaunch
   both engines and compare source-backed balance, entry IDs, minor units,
   ordered receipt hashes and deleted inventories. Exercise crash injection
   with app process killed between prepared/committed transactions. Do not
   flip source pointers just to make a test pass.
6. For every route in the list below, retain an independent **app-origin
   runtime evidence artifact** with: reviewed APK SHA/certificate, phone
   token, precise route, source witness generation/digest, pre/post
   consistency and error-path outcome. Never manually edit a JSON route
   boolean into "passed". A reviewer must match route evidence to
   source-backed outputs without collecting financial secrets.
7. A signed APK launch/login, Android Widget cold reopen, OS-backed key
   recovery, authenticated encrypted backup, receipt hash parity, full
   delete/reset and two-phone source-backed restore must **all pass** before
   independent approval. Firebase privacy/Data Safety/account deletion and
   Crashlytics checks remain separate blockers. Google Play is LAST.

## All 24 live routes requiring distinct physical-device proof

| # | Route | Required evidence |
|---|---|---|
| 1 | appStartup | cold start uses intended finance authority |
| 2 | widgetStartup | standalone widget cold start uses same source |
| 3 | dashboardRead | real SQL-backed balance, no empty fallback |
| 4 | widgetRead | same transaction generation under engine restart |
| 5 | manualTransactionSave | durable halala-accurate append |
| 6 | bulkSmsConfirmedSave | 1–100 confirmed SMS, deduped and replay-safe |
| 7 | widgetSmsConfirmedSave | independent widget append cross-engine CAS |
| 8 | transactionEdit | persist edited values and attachment identity |
| 9 | transactionDeleteAndUndo | 30-day encrypted tombstone and restore |
| 10 | deleteAllTransactions | consent, receipts and typed SQL parity |
| 11 | categoryCatalogInstall | atomic catalog version and typed rows |
| 12 | categoryCreateEditDeleteRestore | restored labels and zeroed budgets |
| 13 | goalCreateEditDeleteRestore | preserved history, reset saved amount |
| 14 | recurringCreateEditDeleteRestore | recurrence and tombstone consistency |
| 15 | recurringPostingAndPostponement | one confirmed, atomic recurring posting |
| 16 | challengeAndBudgetUpdate | CAS preserves concurrent widgets |
| 17 | merchantRulesAndSmsHashes | SHA256 hash integrity and no raw SMS |
| 18 | receiptCopyAndAttach | real image bytes encrypted and reopened |
| 19 | receiptView | decrypted view bound to same transaction |
| 20 | receiptRemoveAndRollback | encrypted recycle, expiry and undo |
| 21 | widgetBalanceRefresh | correct refreshed balance after cold restart |
| 22 | backupExport | authenticated portable finance and receipts |
| 23 | backupRestore | phone A → phone B exact digest/amount/invoice parity |
| 24 | fullFinanceReset | biometric, saved backup and exact deletion consent |

**Source release remains NO-GO** until all 24 independently witnessed,
migration/rollback and real hardware acceptance are completed. No "24/24"
claim may be inferred from a green CI report.
