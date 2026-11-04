# M448 — Account-context finance behavior (stacked on M440)

Status: **partial implementation / Draft only**. Do not merge or release this branch until account source, UI and backup gates pass.

## Approved rules

1. Goals live in an independent savings wallet. Creation does not debit a bank. The savings overview displays the total goal balance, while a selected bank displays only *traceable funding movements* from that account. Wallet-funded due payments only debit the bank for their confirmed current-cash portion, never the wallet portion again.
2. Each recurring payment has a stored default account. The open dashboard account does not change its payment source. An explicit override is either **this payment only** or **future payments**. Reminders have no financial side effects.
3. Budgets are independent of accounts/categories. A selected account view shows its spend and the all-accounts total. Thresholds use the latter, including confirmed allocations from other accounts.
4. SMS review must rely on unambiguous bank+last-four evidence. No evidence or multiple matches leave the entry without an account, subject to user choice. The open cash tab is not an SMS account guess.
5. Accountless transactions remain in the overall ledger and income/expense totals. They are filtered for later association and do not change a particular account balance until explicitly linked through the witnessed finance writer.

## What this PR currently implements

- Read-only version-checked SQLCipher projections for named standalone budget totals (selected account + all accounts), traceable source-specific goal contributions and unlinked historical entries.
- Fail-closed bank SMS account evidence resolution, with no reliance on the Home header.
- Recurring account change-scope and cash-vs-goal-wallet payment policies. These are pure calculations, not live money writers.
- Unit and disposable encrypted database regression tests.

## Still blocked and not represented as complete

- User-facing budget, goal, recurring and SMS review UI must call these policies and projections through the shared verified Home/Widget SQLCipher lock.
- Persistent recurring defaults and account-sourced goal funding require witnessed atomic edits to the canonical snapshot and typed SQL. Existing goal funding movements do not record every source; never backfill guesses.
- Portable backup V3 must include any added per-goal/per-recurring account metadata, with tested restore and rollback. Do not add unbacked-up tables.
- Accountless re-link needs an explicit reviewed action with stale-generation protection. Avoid retroactively posting income or expense twice.
- Validate the exact PR HEAD in Flutter/SQLCipher CI and later on signed Android builds using both test phones.

PR base is the account-feature branch for #359, not main, so this change remains a separate reviewable stack. After #359 merges, retarget to main only after rechecking the diff.
