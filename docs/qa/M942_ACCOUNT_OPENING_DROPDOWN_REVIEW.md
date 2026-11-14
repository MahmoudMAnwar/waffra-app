# M942 — child bank-account opening balances and inline dropdowns

Issue #649. New Draft PR based on main, independent of #648. Changes and tests are owner-approved; not released.

## Money source and acceptance
- Every created bank/wallet/cash account is a SQLCipher `fresh_finance_money_accounts` row with exact `opening_minor` in halalas and a separately authenticated bank/provider identity. One selected institution groups multiple *independent* accounts, not an additional bank balance. Account total is the integer sum of verified active balances.
- Cover a single selected bank with two distinct account IDs and opening amounts (e.g. 5,000 and 2,000 SAR). Verify balances 5,000 and 2,000, total 7,000 before and after close/reopen and no source entry inserted from opening.
- Dashboard forecasts and budget projection must use the same verified all-account total, excluding historical unassigned entries and double-posted opening. Until verified source loads, show a nonnumeric placeholder rather than a forged forecast balance; distinguish pending income/expense *forecasts* from confirmed available cash.
- All catalog local/digital bank and wallet choices must obey exact child group identity before the writer commits. Unknown legacy institution grouping cannot authorize a false same-bank child. Cancel leaves SQLCipher and UI selection unchanged.
- Direct bank SMS and sender-group review must offer verified in-context create, retaining original full-message review and user confirmation. Existing entry confirmation and account generation must be refreshed after account creation.
- No changes to finance writers/SQL schema, biometrics, core backup, SMS inference, original +, Snackbar, or previously approved Home/Goals/Recurring cards. User's real backup and both Android devices are **not** tested in this CI stage.

## Regression matrix
1. Bank provider group resolves for all categories; wallet cannot become a bank child; unsupported/legacy child is refused before create.
2. Account opening SAR parser keeps 2 decimal halalas, rejects negative and malformed amounts, 0 allowed; distinct children persist after encrypted reopen; no auto-income.
3. Manual income/expense, transfer source/destination, goal, recurring and SMS picker use verified account add and full account refresh; cancellation no side effect.
4. Projected account balance shows account openings + verified posted entries, net-zero transfers, subsequent goal debits, never transaction-only legacy net; before verified read no false number.
5. Exact SHA CI full Flutter + M550 + M449 release notes; source tests supplement but do not substitute for Android end-to-end.

**Status:** implementation in progress; CI/physical device acceptance pending.
