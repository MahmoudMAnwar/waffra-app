# M440 — Saudi accounts and internal transfers

**Status:** SQLCipher backend development (not yet activated in a released APK).

## Requested product behavior

The user may create SAR accounts of type cash, bank, wallet or other; choose a
source account on a new income/expense entry; and choose two distinct accounts
for a third transaction type **Transfer / تحويل**. An internal transfer moves
value from one account to another without changing global net worth or being
counted as income, spending, budget spending or savings.

## This initial commit

- Three SQLCipher account-domain tables with a schema revision marker and
  foreign-key integrity checks.
- Account opening balance, renaming, guarded archive and current balance
  computed from actual account-linked finance entries and internal transfers.
- One immutable transfer row per requested move (idempotent retry).
- Historical entries may be *linked*, never copied/reclassified, only with
  explicit user consent and independently verified migration evidence.
- Tests for double submit, bad destination, conserved total, legacy integrity,
  SQLCipher persistence after reopen and source fail-closed behavior.

## Blockers for full live integration

The currently shipped financial source is guarded legacy storage, and the
encrypted SQLCipher cutover is intentionally not certified. The new account
repository is **not** wired to user-facing Home/Widget/SMS writes yet. A live
transfer UI must not start a second source of truth. Next development must
connect all three modes to the same certified finance authority, complete
legacy migration, backup and restore, and signed Android phone validation.

**No automatic cutover, no deletion of old entries and no weakening of CI or
privacy checks are authorized.**

UI prototype: `WaffraAccountTransactionForm` now offers Income, Expense and Transfer; transfer requires source and destination account and only commits through an injected authoritative callback. This widget is intentionally not inserted into Home until the source writer and migration are certified.

## M440 follow-up implementation — source safety and migration

- Account transfers and account changes now have a verified, source-witnessed
  SQLCipher gateway using the same native Home/Widget writer lock. Every
  change advances the canonical finance generation alongside typed SQL.
- Confirmed manual income/expense may now be linked to a chosen account
  **inside** the existing unified SQLCipher entry writer transaction.
  It requires the exact displayed generation and rejects missing or archived
  accounts. Unrelated SMS and widget writes remain unchanged.
- Added a read-only, source-digested legacy migration preview. It does not
  invent an account or rewrite any historic entry. Wallet-funded goal dues
  are reconciled as goal-wallet/cash portions, never charged twice.
- Added a fail-closed portable V2 export check: the old password-encrypted
  backup format cannot represent these new account tables. An account-aware
  restore format must be implemented and verified before release.

### Unfinished release gates

1. Account-aware portable backup + atomic restore, with actual two-device
   rollback/reopen tests and no old-user loss.
2. Connect account/category/budget choices into the live manual transaction
   form on the selected finance source; do not expose a partial user flow.
3. Reconcile all old ledger entries to an explicit account with user consent,
   verify signed app/widget/SMS source parity and approve SQLCipher cutover.
4. Complete exact-HEAD CI and signed Android checks before leaving Draft.

**Do not treat this PR as a user-installable account feature yet.**

## M440 CI repair (2026-11-04)
- Exact-head `Waffra Android encrypted DB integration` failed before financial assertions because hosted runner reported only 5680MB available versus 7373MB needed for AVD userdata. Primary/retry emulator userdata set to 3072MB and nonessential hosted toolchains reclaimed. Both emulator tests remain mandatory; this is not account activation evidence.

## M440 New-account zero opening regression (2026-11-04)
- Account creation accepts valid zero SAR opening amounts in Western/Arabic/Persian digits (including 0.00), while ordinary income, expense and transfer amounts stay strictly positive. No auto-created balance or transaction.

## M440 same-transfer replay semantics (2026-11-04)
- Repository returns false only when transfer id and all source/destination/amount/date/note fields match the already committed row; manager no longer converts this benign idempotent confirmation into a user-facing failed save. Mismatched replay still throws and does not post a second transfer.

## M440 account-linked entry and portable V3 work (2026-11-04)

- The unified SQLCipher writer accepts an **explicit account per confirmed
  transaction** in a batch. SMS digest dedupe, a canonical generation witness,
  account-active checks and account-link insertion live inside one transaction.
  A skipped duplicate digest does not create a second account entry or link.
- Account manager now sends classified manual income/expense through the
  verified SQLCipher bridge; transfer remains one idempotent non-income ledger
  row. Manual input requires title and category before submission.
- Portable **V3** is a password-authenticated wrapper containing an authenticated
  full V2 finance/receipt archive plus typed account rows, account associations
  and internal transfers. The export is captured under the same source lock.
  Restoration validates cross-references and restores to an empty disposable
  encrypted vault with one enclosing transaction. Traditional V2 exports
  continue to refuse existing account data to avoid silent loss.
- Added account V3 roundtrip/tampering tests, SMS and recurring association
  regression cases, and a dedicated targeted GitHub Actions workflow.
- **Not production activated**: the published Home/Widget source binder still
  requires separately signed cutover evidence. No account selection from the
  real bank-SMS UI or recurring UI has been enabled until that gate and
  category/budget selection can be verified on the same source. This PR must
  not be merged until conflicts and exact-head CI have been addressed.
