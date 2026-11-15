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
