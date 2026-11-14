# M935 — Phase Two financial parity & Android hardware acceptance

**Owner request:** complete all code-side Phase Two checks and hand over only genuine physical-device tasks.
**Issue:** [#639](https://github.com/MahmoudMAnwar/waffra-app/issues/639).
**PR:** record the new Draft PR link after creation. **Status: Partial / Hardware UAT pending.**

## CI-side acceptance (synthetic only)

| Check | Responsible | Evidence | Status |
|---|---|---|---|
| Authenticated legacy V24→V3 conversion | Repository CI | `test/storage/m935_phase_two_restore_finance_acceptance_test.dart` | Implemented, exact-HEAD CI pending |
| Cold SQLCipher reopen on two independent disposable stores | Repository CI | same Dart test; different local test keys, no live DB | Implemented, exact-HEAD CI pending |
| Unique historical entry IDs and 19→38 rejection | Repository CI | real identity guard on archive and cold ledgers | Implemented, exact-HEAD CI pending |
| Halala income, expenses and net; no fabricated bank account | Repository CI | SQL sums, account repository, verified finance snapshot and authoritative widget calculator | Implemented, exact-HEAD CI pending |
| Categories, budgets, goals, recurring and entry allocation preservation | Repository CI | original typed V3 history equality after cold reopen | Implemented, exact-HEAD CI pending |
| PDF, widget, rollback and source-read protection | Repository CI | source assertions and existing M618/M620/M630/M448 tests; complete `flutter test` | Existing + source contracts, exact-HEAD CI pending |
| Android UI, export rendering, device speed, real encrypted backup | User/test hardware | private UAT record below | **Pending device evidence** |

**Strict limits:** CI on Linux is *not* an Android screen/render benchmark, *not* a phone SQLCipher migration of an owner's original archive, and *not* authorization to upgrade any device containing unique financial data. New assertions do not weaken SQLCipher source integrity, rollback, owner-authentication, or any existing negative test. No real data or password enters GitHub.

To run the focused fixture on a developer machine with the project's verified native SQLite3MC dependencies:

```bash
flutter test test/storage/m935_phase_two_restore_finance_acceptance_test.dart
flutter test test/storage/m614_legacy_v24_restore_test.dart test/storage/m616_android_v24_restore_test.dart test/storage/m618_v24_preflight_history_parity_test.dart test/storage/m620_restored_home_ledger_parity_test.dart
```

The existing exact-head full Flutter workflows discover the new test automatically. Do not create another redundant full-suite CI workflow.

## User-only tests — on the expendable Android handset FIRST

1. **Preserve source evidence privately.** Keep the original encrypted `.waffra` file unchanged and separately saved; record only a SHA-256/checksum, app build SHA, original transaction count, income total, expense total, goal count, recurring count and category count. Never post names, amounts, password, SMS or the original file in a public GitHub issue. If any file is not reliably saved, stop.
2. **Install the reviewed main APK on the expendable test phone** that has no important data. Verify first login, permissions, notifications, fingerprint, splash and Home. Avoid the spouse's phone entirely for this rehearsal.
3. **Restore an authenticated copy of the older backup** to the expendable handset with its real password entered only on the device. Record stage code on failure (AUTH, V24_STAGING, SQL_PREFLIGHT, SQL_APPLY, CANONICAL_PARITY, HOME_PARITY), not secrets. If receipt images are unavailable, confirm the app's explicit warning; do not interpret missing images as restored.
4. **Financial parity before and after force-stop/relaunch:** verify exactly the same number of distinct transactions and original IDs (where exposed); no duplicates; compare income, expense and signed historical net in SAR/halalas; bank accounts stay at zero/empty when the archive contains no bank accounts. Historical unassigned money is *not* a newly invented bank balance. Re-open Home, Goals, Recurring, Budgets and Trash to verify counts and associations.
5. **PDF on Android:** export with zero items (must reject), then with restored transactions. Compare income, expenses, net and exact included date range / account filter with Home; verify Riyal symbol, row count, multiline text, no reversed digits, no clipped table/chart. Never upload an unredacted financial PDF.
6. **Finance mutations on test data only:** manual income and expense, transfer between two user-created test accounts, goal funding, linked recurring due and duplicate SMS review. Before/after account balance must change exactly once; internal transfer preserves combined net; transactions appear once; receipts and categories survive relaunch; failed save/restore does not change the financial snapshot.
7. **Performance + UI on the actual Android device:** record device model, Android version, APK SHA, cold/warm login, biometric→Home, logout→login, SMS 1/100/1,000–2,000 review paging, restore duration, PDF export 100/1,000 rows, and whether any freeze/black frame occurs. Visually inspect overflow at native and 200% text, Arabic/English and system light/dark; snackbars stay above footer and **must never move the global + FAB**. Report actual metrics; do not equate host timings to FPS.

### Go / No-go

- Any **19→38** (or any other doubled transaction count), zeroed historical net, account-balance substitution, missing row, missing budget/goal/due link, extra debit, or crash/rollback discrepancy is a **NO-GO**: do not merge a corrective PR or upgrade spouse phone; capture sanitized device symptoms and report a new defect.
- Only after all test-handset finance/data/UX checkpoints pass may the owner separately decide whether to update the spouse's handset, **with its existing independently verified offline backup preserved first**. No automatic upgrade/restore of that device from this PR.
- Only the owner can mark device UAT **Done** after examining actual hardware results. Repository CI success alone leaves this stage **Partial**.

### Private result record (fill without sensitive data)

| Field | Value |
|---|---|
| Test handset / Android OS | Pending |
| Installed APK/main SHA | Pending |
| Backup file SHA-256 (never file/password) | Pending |
| Before vs restored transaction IDs/count | Pending |
| Before vs restored signed totals / account balances | Pending |
| Goal/recurring/budget/category parity | Pending |
| Post force-stop / second open equality | Pending |
| PDF totals and visual check | Pending |
| Login/SMS/restore/PDF latency and any freeze | Pending |
| Overflow/FAB/snackbar evidence (redacted) | Pending |
| Spouse device approved for update? | **No — pending owner acceptance** |
