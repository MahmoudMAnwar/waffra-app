# M944 — five-axis implementation and verification matrix

Issue: #653. Branch: `feat/m944-five-axis-code-reliability-20261115`. Draft PR, based on main after #650 and #652.

| Axis | Implementation evidence | Regressions | Same-head CI | Status |
|---|---|---|---|---|
| 1. SQLCipher database paging | Keyset source pager + verified API bridge + account history cursor UI committed | 2,700 SQLCipher rows, account/month scope, ties, duplicate-free pages, cold reopen and M611 source contract added (not yet run) | Pending | Partial |
| 2. Large lists / sender review | Account history uses keyset; Home and unified activity now render in 50-card progressive windows; native SMS cursor and goals/recurring profiling remain pending | Added M944 Home window + existing full filtered PDF contract tests (not yet passed) | Pending | Partial |
| 3. Financial parity | No financial writer changes; new replay/idempotence and opening parity SQLCipher test committed | 81 transfers, replay, conflicting ID, unapproved move, original openings, net zero, no ledger income, cold reopen (not yet run); V24/V3 restore matrix still pending | Pending | Partial |
| 4. Home state extraction | Extracted original 246-line Home shell verbatim to `waffra_home_root_shell.part.dart`; extracted original 304-line recurring editor/due workflows verbatim to `waffra_home_recurring_workflows.part.dart`; added real part registrations and fail-closed Dart/Python reconstructed source tests | Structural M944 plus M707/M830/M644/M938, M622/M623 historical layout/source contracts updated where original file moved | Pending exact-HEAD CI | Partial |
| 5. CI failure diagnostics | Not implemented | Pending | Pending | Pending |

## Non-negotiable invariants
- All financial account scopes and sums require verified SQLCipher; no source guessing, legacy fallback, new money writer, bank-opening inference, or unsigned device claim.
- Never change the approved Home / Goals / Recurring cards, + FAB, Snackbar, SMS original text and full sender-group select-all / exclusion.
- Avoid a false performance claim: a host disposable SQLCipher run is not Android FPS / user backup proof.
- Every production/test code change must be explicitly bounded by `docs/qa/approved_change_scope.json` and pass M385/M550.
- Mark an axis Done only with committed code, executing automated tests, and passing exact-HEAD CI; otherwise use Partial/Pending.

## Axis 4 source audit (2026-11-15)
- Compared original production `main.dart` Home root method body to extracted part text with only the declaration renamed: **12,053 of 12,053 characters match**.
- Compared original Goals/Recurring block to extracted workflows method text: **15,906 of 15,906 characters match**; replacing the one marker reconstructs the original page-part bytes exactly.
- New Home state still intentionally owns State lifecycle, owners/authorization/source leases, writable presentation fields and tiny event routing. Splitting these into wrappers without a verified benefit would add stale state and complicate dispose; do not count line reductions alone as safety proof.
- Full source-contract/Flutter/Android CI on the exact PR head remains required before marking this axis Done; physical device screenshots and owner-backup parity are not implied.

## M945 — owner-reported restoration/UI follow-up (Nov 15 2026; same #654)
- Added read-only finance cache invalidation after all three verified ledger-replace branches in manual/SMS sheet and after failed-save optimistic rollback; confirmed manual append requests authenticated account refresh. No storage writer rewrite.
- Goals/Dues count-bearing dropdowns replace redundant filter icon and default chip. Goals overflow keeps Deleted only; SAR money uses native currency widget. Dues adds gold aggregate strip and empty-state Add button while retaining reminders/linked goal and due cards.
- The Home activities Show more/less is now a single in-toolbar control, with the verified combined transfer/savings total rather than two separated buttons; read windows remain capped at 50 per action.
- Added synthetic 19-to-20 ledger index test with two old incomes, widget/DOM source QA and updated M944 assertions. These are not evidence that the actual encrypted owner archive (password unavailable) contains or restored five goals and both income rows. Same-head CI and physical Android UAT pending.

## M946 — proactive smoke over ALL current app areas, same Draft #654 (2026-11-15)
- Owner-requested 33-feature smoke matrix in scripts/qa/m946_full_app_smoke_matrix.py: source-referenced runnable Dart tests, mandatory self-tests, and no pretend hardware green. 60 distinct Flutter tests, grouped into money/experience/safety; run on **every PR update**, regardless of path and on main, each against exact head SHA.
- New synthetic SQLCipher end-to-end smoke covers bank/wallet opening balance, manual income/expense, account-specific history filtering, cold reopen, historical unassigned records, duplicate blocked writers, and reviewed-SMS replay with one credit only.
- Reconciled obsolete Home activity expansion assertions in M296 without removing tests: the only button now lives in the original operations toolbar and reflects verified unified activity count.
- CI job writes actual JSON/Markdown test pass-fail-skip evidence per group through existing M937 parser and archives feature matrix and results. Existing full offline finance regression still independently tests all Flutter suites.
- IMPORTANT: code uploaded does not equal passing CI, and Flutter tests cannot validate real Android permissions, OS notifications, bank SMS delivery, visual overflow or owner password-encrypted restore; record those gaps separately until device acceptance.

## M947 — destructive-action end-to-end smoke and 19-row retention (Nov 15)
- Prior M946 inventory did NOT test encrypted transaction deletion; owner called it out. Added real SQLCipher 19-row source/ledger parity test in M183: declines deletion, deletes one expense, verifies both incomes and eighteen other identities survive, cold reopens and undoes to the original nineteen. Also verifies old SMS dedup fingerprint remains.
- Added UI source contract for confirmed-only commit, source-witness and receipt verification, no navigation replacement/reset, index invalidation, Delete All and biometric full-vault reset distinct flows.
- Added mandatory M946 smoke paths for SQL transaction and receipt recycle, 30-day Goals/Recurring/category restoration, SMS inbox delete, Delete All, and cloud account release guard. These source contracts do not replace on-device OS permissions, visual black-screen, or biometric testing.
- Actual head CI outcome, including Passed/Failed/Skipped, remains separate; tests are not claimed passing merely because code was pushed.

## M948 — New property/load/host-UX and evidence gates (2026-11-15, #654)
- Found real bug: Home calendar range started at selected start-minus-one-day. Fixed in the shared read-only filter with exact inclusive day-only comparison; tests include yesterday-at-23:59, next-day-at-00:00, end of year and leap February.
- New runnable `test/m948_financial_properties_and_performance_test.dart`: 10,000 seeded ledger records vs independent brute-force reference, account-filter and page exactness, 50-card cache invalidation, 10,000 integer-halalas, 16-year due calendars, and 320px RTL/200% text fixture. The 15-second limit measures *host index* only.
- Expanded real encrypted SQLCipher M946 test with parallel manual/SMS writers at one witnessed generation (only one may commit) and invalid/cancelled account/user/receipt input rollback; encrypted cold reopen verifies the winner ID and balance.
- Added fail-closed `scripts/qa/m948_smoke_quality_gate.py` and mutation test: rejects skipped/failing/incomplete test evidence, missing events, wrong commit, invalid totals and false Android verification. M946 CI now invokes this gate after producing M937 report and statically analyzes new Dart suites.
- All fixture data is synthetic. Real owner archive, Android biometric/notification delivery and black-screen/lag remain NOT physically tested by host suite.
