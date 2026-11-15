# M955 — Verified Home finance summary without loading ledger cards (Issue #664)

Stacked work on #658 / Issue #657. PR base is `feat/m952-five-axes-followup-20261115`, not main, so the M952 financial hardening remains a prerequisite and the #660 UI/SMS branch stays independent.

## Five-axis continuation

1. **Finance integrity**: exact-halala budget and goal source authority stays identical; no new writer, balance update, schema migration or ledger backfill.
2. **Accounts & legacy restore**: only active owner-verified SQLCipher under a finance witness; absent finance tables fail closed, no empty account creation.
3. **Performance**: currently the Home selected-account header requests `summaryOnly:true`, but `WaffraAccountContextRead.load` still deserializes every current-month transaction row that Home never displays from `context.entries`. Add opt-in `includeEntries:false` solely for Home; keep normal ledger/account context pages unchanged.
4. **UI stability**: do not change fixed +, approved Home/Goal/Due cards, Arabic/RTL, Snackbar or screenshots. Selected account visibility still depends on verified context and complete associated source IDs.
5. **QA / architecture**: add real encrypted many-entry parity test to prove that the optimized Home summary contains zero hydrated ledger cards yet identical goals, budget limits and selected/global halalas. Register it in mandatory exact-HEAD M946. Preserve legacy full/month pagination and data ownership.

## Invariants and blockers

- `includeEntries` defaults to true and does not change any existing read caller except the new Home-only opt-in.
- Still read all independently verified account membership IDs for historical filters; those are not the same as current-month ledger card hydration.
- Snapshot before/after witness, native source lock, SQLCipher domain check and no finance mutation remain.
- Existing account context page and export use unchanged entry lists.
- No claim that five axes are 100% or that owner private old V3 Backup/Restore / Android handset FPS and geometry have been tested. Follow-up structural Home extraction and account membership scaling remain separate.
- Review and tests must pass on the exact PR SHA; avoid skipped test counts.

## Second code tranche: source-level SQLCipher budget aggregation

- When `includeEntries:false` only, `WaffraAccountContextRead.load` now groups that month's actual encrypted `fresh_finance_standalone_allocations` by budget ID inside SQLite (`SUM(INTEGER)`), instead of fetching every month allocation into a Dart list on each Home account refresh. Active source budgets and their positive limits remain authoritative; unassigned expenses contribute globally but not to a selected bank. Null/all-account context cannot silently match an account, and invalid expense allocation amounts fail closed.
- Normal Account Context screen `includeEntries:true` deliberately preserves the earlier pure one-pass Dart aggregation and full ledger read, ensuring the legacy accounting/export semantics cannot drift.
- The 900-row real encrypted regression compares BOTH paths over bank, wallet and all accounts, two spending budgets plus a zero-spend active budget and an archived budget (which must stay excluded), receipts with unassigned/older-month entries, exact goal funding and cold SQLCipher reopen, and ensures no mutation of bank balances or entry count. Existing M952 10,000-row/120-budget policy parity remains required. Performance claim is reduced Dart row materialization for Home only; no Android FPS or private archive numbers invented.

## Accountless older-history safety (additional executable SQLCipher scenario)

- In a second clean disposable encrypted vault, create historical expense, income, explicitly confirmed budget allocation and independently saved goal wallet, but deliberately **no** money accounts or account links. Validate regular vs compact read parity, 7,000 global spent / zero selected bank spent, 15,000 saved goal wallet / zero account funding; after a cold reopen, source entry count stays 2 and no money account is guessed or created. This models the typed accountless state of old archives only; it is NOT a claim that the owner's particular password-protected original backup restored correctly. Do not replace a verified missing bank balance with an unverified historical ledger net.

## M956 — atomic Home owner-verified account view (code-only follow-up, same Draft #665)

- Previously the Home header obtained balances, selected-month compact budgets/goals, and complete historical account-entry IDs via **three separately locked** API reads. A financial commit between calls could present a mixed-generation selected-account header; the same owner-lock overhead was repeated three times.
- The new `readVerifiedHomeAccountView` verifies the activated SQLCipher source, captures one pre/post finance snapshot under **one** `WaffraExperimentalWriterGate.withExclusiveAccess`, resolves stale or archived selected accounts against that same verified account list, and queries ledger-free month summaries and all-time entry IDs without releasing the gate. Generation and digest must both match or the Home display fails closed.
- Home retains its prior session epoch/cancellation safeguards and the same exact account ID filters and UI widgets. No money mutation, parent/child reassignment, ledger fallback or migration occurs. Other API callers still have their existing contracts.
- `test/storage/m955_home_verified_summary_parity_test.dart` and `test/m467_account_header_test.dart` now assert the single-lock wiring, source-witness conditions, stale selection resolution, and maintain the already registered real SQLCipher 900-row/legacy bankless parity coverage. Physical UAT and actual owner backup acceptance remain outstanding.

- M956 adds an independently activated/encrypted bridge integration case using an ephemeral first-run owner source: compare atomic vs legacy separately witnessed reads for a user-approved 2,350.50 SAR account, validate unknown account falls back to all, and assert exact digest/generation and balance before/after. This is a test vault, never the owner's real backup.

- Additional M956 race/fallback guard: record the pre-query requested account ID. If a selected bank was archived/deleted, the verified result must resolve to all and apply once; comparing the currently selected ID against the **resolved** fallback previously caused repeated re-reads. Only a real concurrent user selection change should enqueue a retry. M467 and M955 source contracts assert this condition; actual Android click-through is still unverified.

## M957 — correction of two outdated but mandatory regression witnesses

- The M946 safety shard and money shard and M147 full Flutter suite exposed two outdated **source-only** checks (M468/M470) that still expected the previous three independent SQLCipher Home reads. Their original behavioral aims (no duplicate background scans, no `none` account choice, no stale account membership) remain.
- Update their assertions to check the authenticated one-lock M956 API call, preserved exact account membership, separate epoch and requested-account stale response guard. The remaining tests within both files stay unchanged and enabled. This is a test-contract migration driven by actual exact-SHA failures, not relaxing the gate or fabricating device results.

## M958 — Eliminate redundant zero-row ledger query

- The compact verified Home summary no longer submits a transaction-card SELECT/JOIN/ORDER BY with `LIMIT 0`; it skips that SQL read entirely. Default full-context reads still run their original ledger query and return immutable source-backed rows in their original order.
- The SQLCipher account/goal/budget read and source generation/digest witness are unchanged. A new source contract runs alongside existing 900-entry and accountless cold-reopen encrypted tests. No money writer, private restore, FAB/Snackbar or Android UI layout changed. This is a bounded performance improvement, not five-axis completion.

## M959 — Stale asynchronous account-read error does not erase later choice

- When a previous verified SQLCipher account view fails after the owner has chosen a different account, the catch path now detects the superseded request and schedules the existing witnessed rerun. It preserves the new selection, invalidates the old budget/ledger-ID context and prevents numeric balances from being displayed as authenticated until the current read passes. Session epoch and shutdown protections remain the first guard.
- An extra M467 source contract asserts this failure path; the same encrypted integration remains required. No financial mutation or visual redesign.

## M960 — Grouped owner-verified account balance arithmetic

- The previously per-account correlated income/expense, current-cash goal due, inbound/outbound transfer, and goal wallet-source sum is now four independently grouped SQLCipher source CTE projections joined once to each account; each bank/wallet/archived account keeps exactly the same integer halala outcome, schema witness and account display order. No joins multiply unrelated money streams.
- Mandatory disposable SQLCipher regression with 360 source transactions, 12 two-sided transfers, a partial due split, 3 attributed goal movements and a bankless/archived account verifies new vs original SQL byte-for-byte IDs and amounts and repeats after encrypted cold reopen. No finance write, private backup or Android acceptance implied.

## M961 — immutable month and last-account display view cache

- The current read-session `WaffraFinancePeriodIndex` reuses a single unmodifiable list per month. `WaffraHomeLedgerReadCache.scopedMonth` keeps only the latest result for one exact immutable month list and the owner-verified account-ID set by identity. The existing ledger `invalidate()` drops all caches; even an equal-value but newly witnessed ID set is re-filtered. No account cash is calculated or reassigned.
- The mandatory M946 experience test seeds 12,000 synthetic ledger entries and asserts source order, stable repeated identity, bank A→B isolation, fresh account witness, other months, and invalidation after insertion. Original Home/Goals/Dues/Snackbar/FAB unchanged. This tests host logic, not handset FPS.

- Cache-safety contract: `WaffraAccountContextRead.loadAccountEntryIds` returns an unmodifiable SQLCipher-witnessed ID set. UI callers must never mutate that set in place; each new owner source witness supplies a fresh set object and therefore recomputes filtered month data. The ledger index is explicitly rebuilt after existing write/restore invalidation, not by guessing from a bank name or relying on a timer.

## M963 — verified edit Undo refreshes bank summary

- The main editor already refreshes verified accounts on ordinary successful Save; no extra refresh was added there. The direct Snackbar Undo path bypassed that parent call after an authenticated metadata/amount/date rollback. It now queues the existing source-witnessed account refresh only after successful Undo, keeping balance and budget context current. Account linking/moving still has no misleading metadata-only Undo. Registered in M946 experience with existing encrypted history-edit integration coverage.
