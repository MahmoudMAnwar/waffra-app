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
