# M952 — Proactive Financial Reliability & Code Hardening (Issue #657, Draft PR #658)

Baseline: merged #654/M944 and #656/M949–M951; **115 new functional Dart cases are already on main**, and are not double-counted here.

This is the *latest* 2026-11-15 five-axis plan of 20 proposed hardening improvements. It is **not** the old numbered M944 five-axis plan.

| Axis | Verified existing baseline | New M952 code tranche | Test / evidence | Current status |
|---|---|---|---|---|
| 1. Financial integrity | Verified encrypted authority, fixed halalas, duplicate suppression and transfer/goal/due rules | Finance-domain readiness now fails closed for missing goal wallet, due settlements or budget link tables; monthly budgets aggregate exact halalas once, preserving all existing postings | Extended encrypted schema tests + 10k-entry/120-budget original-policy parity | **Partial**; exact new HEAD CI pending |
| 2. Accounts and Backup/Restore integration | Portable V3 archive, V24 guarded restore, account links | Account-read gate validates versioned domain/FK plus missing dues/budget tables; historical unassigned reconciliation uses source-verified keyset without creating accounts | Encrypted missing-table cases; existing V3/V24 archive suites and 2700-row keyset parity | **Partial**; private legacy archive still not tested |
| 3. Performance and responsiveness | Verified monthly source keyset, 50-card Home/100-card SMS window | Cache complete sender IDs; remove the remaining historical **unassigned OFFSET path** in the actual Account Context screen; eliminate O(entries × budgets) repeated scan by O(entries + budgets) single pass | M940 + 2700-row SQLCipher tied-date/old-month keyset regression + 10k postings/120 budgets synthetic parity | **Partial**; full Home snapshot avoidance and physical FPS remain |
| 4. UI stability | Approved Home/Goals/Dues, static +, snackbar and RTL | No visual or navigation design change in either tranche; unassigned screen retains previous/next controls with cursor-bound behavior | Existing M274/M948 widget matrix plus M611 page source contract; physical Android screenshots still required | **Audit only** |
| 5. Architecture and proactive QA | M944 extracted Home parts and M949–M951 nonduplicate cases | M937 rejects duplicate runner/suite and missing suite provenance; money budget aggregation moved to pure policy; SQLCipher pagination is reused rather than duplicate screen implementations | Three hostile reporter tests, M611, M944 and new M952 budget/schema cases | **Partial**; further Home module separation and CI exact HEAD pending |

## Invariants and decisions

- Never treat a schema marker alone as evidence that all linked tables survived a restore or an interrupted migration. The finance-domain check must be read-only and fail closed, never autocreate empty money rows.
- Preserve every already confirmed financial writer, account opening, transfer, linked goal/due, rollback and cold-open invariant; no bank balance guessing.
- SMS list cache represents every sender group ID, not the first 100 visible cards. Native SMS data, selection, and original text stay untouched until explicit existing confirmation.
- Keep UI design, Arabic/English labels, fixed FAB, Snackbar anchor, and old main-part source reconstruction unchanged.
- The 20 proposed improvements are **not** all completed: remaining work includes keyset/offset consolidation, full Home snapshot avoidance, broad high-volume goals/recurring profiling, device/restore end-to-end verification and comprehensive nonduplicate tests.
- Do not mark an axis Done without committed code, relevant executable regression and passing exact-head CI. Physical handset/private encrypted archive acceptance is separate and must not be invented.

## Second code tranche — 2026-11-15 (not 5/5 complete)

- **Scope**: Continue Issue #657 on the SAME Draft PR #658, independent of Draft #660 where owner-requested edit/OTP/UI fixes are being developed. No early merge or transfer of unrelated source changes.
- **Verified historical pagination**: AccountContext `filter='none'` used `readUnassignedPage(offset:pageOffset)`. It now calls `readKeysetHistoryPage(unassignedOnly:true)` under the current verified finance lock; the same end-of-page cursor map serves month and full historical unassigned views and is reset on filter, month or account link change. The legacy public OFFSET read remains for existing tests/callers but not this screen.
- **SQLCipher evidence**: Extend pre-existing M944 2700-row disposable encrypted test to verify all 900 unassigned records (and older-month subset), stable order across same timestamps and any page size, identical first-page results, and rejection of incompatible `accountId`+unassigned combinations.
- **Budget efficiency and financial parity**: Pure `WaffraAccountContextPolicy.budgetSummaries` computes all budgets once from monthly ledger entries rather than repeatedly scanning the same history per budget. A new deterministic 10,000-entry/120-budget regression compares each budget's exact halala global/selected totals, alert thresholds, unassigned expenses and failures to original `budget`. No budget write/ledger modification.
- **Partial restore/read gate**: The existing missing-domain test now includes lost `fresh_finance_goal_due_settlements` and `fresh_finance_standalone_allocations` to prove account context reads reject an incomplete restored finance schema instead of silently presenting zeros.
- **UI/source contract**: M611 asserts the historical review UI uses keyset cursors, retains consent and old navigation keys, and does not switch to an unverified writer or change FAB geometry. Actual owner Android and private legacy archive acceptance are still open.
- **Status**: **0 of 5 axes fully complete**; four have real bounded code contributions and axis 4 remains source-level preservation/audit. The original 20-item concept did not enumerate all 20 concrete task definitions, so do not fabricate a numerical item-completion total. New exact HEAD CI must independently pass before any milestone is marked Done.

## Third code tranche — 2026-11-15 (SQLCipher goals / executable CI)

- **Axis 1, exact-money parity**: Account Context now computes a bank account's independent goal-fund/release contributions with a single grouped SQLCipher query. A nonfunding `due_debit` in the savings wallet must not be construed as an account debit; `saved_minor` remains the independent goal-wallet authority. Zero-sourced goals still appear with zero bank contribution, including when no account is selected.
- **Axes 2/3, high-volume linked-wallet reads**: 80 goals × 9 synthetic encrypted wallet movements (720) seeded in disposable SQLCipher. Compare *every* resulting account contribution for two banks to the previous correlated SQL formula, including release sign, and assert no change to bank balances, wallet totals, IDs or source-row count. No physical-device speedup or private archive acceptance is claimed.
- **Axis 5, run coverage**: Register M952 account/domain schema, 2700-row unassigned keyset, 10k/120-budget parity and the new 80-goal SQLCipher suite in exact-HEAD M946 money/safety shards. A file that only exists on disk is not evidence of a passed CI test.
- **Axis 4**: No approved visible UI, RTL, FAB, Snackbar or navigation geometry is changed by these new storage/CI updates.
- **Gate**: `docs/qa/approved_change_scope.json` explicitly bounds the new goal query and M946 feature registration; `M385`, `M449`, `M550` and the CI suite must still pass on the new commit. This remains *partial* work until remaining Home performance, migration and real Android/legacy-backup acceptance are addressed.

## Fourth code tranche — corrected by actual encrypted CI, 2026-11-15

- **Correction**: the real SQLCipher schema has `UNIQUE(entry_id)` for standalone budget allocations. An entry CANNOT be linked to two standalone budgets. The initial two-budget-for-one-entry test was invalid and correctly failed with SQLite 2067. No schema change or workaround is authorized.
- **Code**: removed unnecessary grouped ledger/keyset allocation joins, restoring the direct unique source join. Retained the independently correct single-pass, source-backed monthly allocation projection and grouped per-account savings-goal contribution query.
- **Test**: the encrypted regression now creates two different budget-linked entries, one unassigned entry and an older-month entry. It explicitly asserts a second allocation for the same entry fails, correct independent budget totals, one bank debit, full/month/keyset uniqueness and unchanged bank balance after reads. M946 executes it on the exact PR head.
- **Acceptance**: no claim of a duplicate-finance production bug or a schema weakness. The failed initial CI run is preserved as evidence, not hidden; all new CI must pass on the corrected commit.
