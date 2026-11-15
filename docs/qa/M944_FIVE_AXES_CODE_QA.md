# M944 — five-axis implementation and verification matrix

Issue: #653. Branch: `feat/m944-five-axis-code-reliability-20261115`. Draft PR, based on main after #650 and #652.

| Axis | Implementation evidence | Regressions | Same-head CI | Status |
|---|---|---|---|---|
| 1. SQLCipher database paging | Keyset source pager + verified API bridge + account history cursor UI committed | 2,700 SQLCipher rows, account/month scope, ties, duplicate-free pages, cold reopen and M611 source contract added (not yet run) | Pending | Partial |
| 2. Large lists / sender review | Account history avoids SQL OFFSET; Home expanded list and full SMS native cursor still pending | Account history paging test pending | Pending | Partial |
| 3. Financial parity | Not implemented | Pending | Pending | Pending |
| 4. Home state extraction | Not implemented | Pending | Pending | Pending |
| 5. CI failure diagnostics | Not implemented | Pending | Pending | Pending |

## Non-negotiable invariants
- All financial account scopes and sums require verified SQLCipher; no source guessing, legacy fallback, new money writer, bank-opening inference, or unsigned device claim.
- Never change the approved Home / Goals / Recurring cards, + FAB, Snackbar, SMS original text and full sender-group select-all / exclusion.
- Avoid a false performance claim: a host disposable SQLCipher run is not Android FPS / user backup proof.
- Every production/test code change must be explicitly bounded by `docs/qa/approved_change_scope.json` and pass M385/M550.
- Mark an axis Done only with committed code, executing automated tests, and passing exact-HEAD CI; otherwise use Partial/Pending.
