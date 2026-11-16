# M1008 — Evidence-driven whole-finance-path audit, Issue #723 / Draft PR #722

Date: 2026-11-16. Status: **Source implementation and automated test evidence pending latest-head CI; physical Android/owner archive not executed.** Do not equate scope inspection, repository static assertions, or a green CI workflow with absence of application bugs.

## Owner-reported screenshots and hypotheses
- Account picker: All accounts, AlinmaPay **-279.35 SAR**, AlRajhiBank **-200.00 SAR**.
- "This month" all-account income **30.00**, expense **279.35**, net **-249.35**.
- AlRajhiBank filtered month: income **30.00**, expense **0.00**, net **+30.00**; Home balance card **-200.00**.
- Arithmetic is consistent for a possible earlier account movement of **-230.00 SAR**. These pictures **do not prove** that this was the user's actual historical transaction; old balance and ledger linkage remain to be verified on the owner's device.
- A selected bank filter is supposed to hide a transaction linked to another account. A **stale linked-entry ID cache after a verified SMS save is not supposed to hide a transaction belonging to the selected account.**

## Confirmed source defects (not guesses)
1. `lib/waffra_home_entry_sheet.part.dart`: successful `commitConfirmedSms` hydrates `entries` and invalidates `_m684Periods` but did not refresh `_m684ScopedEntryIds` or verified account balances before leaving the sheet. Fixed: source read after durable save with explicit post-commit verification warning; no ledger replay.
2. `lib/waffra_home_sms_confirmation.part.dart`: direct `_m565ConfirmSms` omitted BOTH period-index invalidation and selected-account projection refresh. Fixed.
3. `lib/waffra_home_verified_refresh.part.dart`: verified pull-refresh digest short-circuit could return before updating stale account context; changed-ledger refresh replaced entries without invalidating the month index. Fixed in both branches.
4. `lib/waffra_home_verified_account_flows.part.dart`: a save can request refresh while an older account read runs; the caller awaited the old read but not its automatically enqueued newer projection. Fixed by awaiting one verified follower.
5. `lib/waffra_home_transaction_ledger_actions.part.dart` and `lib/waffra_home_delete_all_transactions.part.dart`: verified deletion, undo and delete-all publish updated in-memory entries without promptly presenting new linked account balances. Fixed by triggering/awaiting read-only account refresh; postcommit failure cannot be described as reverted money.
6. Account balance and monthly movement are separate numbers. `monthlySummaryCard` calculates only the selected month's `income-spent`; `_m467ShownBalance` comes from all-time, source-witnessed balances (opening and prior activity). **No automatic "balance correction" was implemented.**

## Cross-feature source audit (scope only; runtime status distinct)

| Area | Source evidence and current check | Finding / remaining gate |
|---|---|---|
| SMS typed income/expense | `entrySheet` and `_m565ConfirmSms` with `commitConfirmedSms` and fingerprint | Two missing readbacks fixed; new M1008 test and existing M470/M983 |
| SMS classification/exclusion | `waffra_sms_local_rules.dart`, `waffra_home_sms_rules.part.dart` | M1007 safe global suggestions, no teaching prompt; conflicts/posted money cannot be silently excluded |
| Two account filters | `_m467ScopedEntries`, `_m684ScopedMonthEntries`, `_m468ReadVerifiedAccountsOnce` | Uses exact SQLCipher linked IDs; P0 cache invalidation fixed |
| All accounts summaries | `monthlySummaryCard`, `readVerifiedHomeAccountView` | Month movement vs all-time balance are not interchangeable; old unassigned entries can appear in All without crediting any account |
| Manual income/expense | `entrySheet` `commitConfirmedManual` | Existing post-commit account refresh present; recheck via M946 money |
| Transfer between own accounts | `_reviewSmsAccountTransfer`, verified transfers journal and `_m648InvalidateTransfers` | Two-sided transfer does not become income/expense; real-device UAT pending |
| Transaction edit/linked account move | `_m953SaveExistingVerifiedEntry`, `editExistingAndMoveAccount` | Account refresh on save/undo exists; concurrent source witness required |
| Delete, undo, delete-all | `_publishVerifiedTransactionLedger`, `confirmDeleteAllEntries` | Stale account presentation fixed; no new delete permissions |
| Recurring and linked-goal payment | `persist`, `settleLinkedGoalDue`, `_loadFinanceSafely` | Source uses verified writer and reload; not modified; real-device cases pending |
| Budget & account separation | `_m684ScopedEntries`, budget allocation SQL joins | Budgets do not change bank balances by themselves; existing source parity required |
| Restore and historical transactions | `_loadFinanceSafely`, restored-ledger parity, prior M1003/M1006 | Owner's old encrypted archive cannot be tested without it; never infer or repair lost balances |
| Background SMS and first Home frame | `waffra_auto_sms_autopost.part.dart`, verified pull refresh | Account/ledger refresh after subsequent Home hydration fixed; Android background delivery UAT pending |
| PDF / search / pagination | `fullFilteredTransactions`, `WaffraFinancePeriodIndex` | Period index invalidation fixed; M940/M944/M946 regression suite must run |

## Executable regression added to mandatory M946
- `test/storage/m1008_two_accounts_sms_reconciliation_test.dart`: three actual owner-confirmed synthetic SMS posts into disposable SQLCipher with two accounts and two months. Checks money in halalas, source-linked exact IDs, current-month net vs all-time balance, duplicate SHA256 hash resistance, and cold reopen persistence.
- `test/m1008_sms_account_projection_refresh_regression_test.dart`: source/UI contracts for both post-commit SMS routes, active-read follower, pull refresh, month index, delete/undo/delete-all, selected account and monthly summary. These are **contracts**, not physical UI end-to-end proof.
- Existing `test/storage/m955_home_verified_summary_parity_test.dart` also registered for the same M946 money feature.
- Mandatory M340/M550/M174/M946 full smoke + native and signed main checks must stay active. Do not count queued, skipped, failed or unexecuted tests as passing.

## Phone acceptance scenarios (not yet run)
1. On device with at least two accounts, record SMS income into bank A and expense into wallet B. Each should appear immediately when its linked account is selected, without restart. All accounts must show both.
2. Switch accounts rapidly while saving SMS and reopening notifications; ensure no old bank view overwrites the new choice.
3. Confirm month net and account balances against real, verified opening/prior activity, with zero fictitious adjustment.
4. Kill/reopen app, pull-to-refresh, confirm counts and balances remain the same; verify duplicate SMS does not post again.
5. Edit a linked amount, move between accounts with explicit consent, delete and Undo. Verify both accounts and monthly summaries.
6. Confirm transfer preserves total assets while affecting both source/destination; check goal due/recurring, PDFs, historical unassigned rows.
7. Restore an authorized old archive in a **throwaway/test device** with rescue backup preserved. Never alter the user's spouse's only backup to try to reproduce.

**Exit status:** Source fixes committed; exact-head checks must be recorded and physical UAT performed before production certification. No guarantee of zero defects.
