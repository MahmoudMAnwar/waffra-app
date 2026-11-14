# M943 / Issue #651 — finance follow-up to M942

Date 2026-11-14. This Draft PR is stacked on `fix/m942-bank-opening-balance-dropdowns-20261114` (#650), not directly on main; never merge out of order. Owner requirements total **8**.

| # | User-approved objective | Status | Acceptance |
|---|---|---|---|
| 1 | Do not display historical income/expense fallback as verified bank balance when SQLCipher unavailable | Pending | Unverified Home header shows a placeholder, not 0 or old net; verified zero account is real 0 |
| 2 | Bound Home rendering/pagination for thousands of operations | Pending | Count and page without all-result list; preserve exact stable date ordering and filters |
| 3 | Remove inverted / unauthenticated month comparison | Pending | No percentage until independently verified historical opening/closing balances exist |
| 4 | Recognize Saudi catalog bank/wallet sender identities safely | Pending | Exact tests for every approved provider, false positives rejected, never auto-post without user approval |
| 5 | Distinguish custom “other” institution children without cross-bank merging | Pending | Persisted and reopen-safe explicit relationship only; no inferred ownership |
| 6 | Permit explicit clearing of saved account suffix | Pending | Atomic SQLCipher delete + rename, user approval, stale witness check |
| 7 | Old V24/V3 backup parity and reconciliation | Pending | Synthetic regression and original device archive evidence tracked separately |
| 8 | Remove dead AI compatibility code where safe | Pending | Confirm runtime graph and keep currency/source negative-security tests; no claims about removed files until validated |

**Invariant:** no unreviewed money write, no SMS auto-post, no account/provider forgery, no changing +/Snackbar/layout, no weakening M385/M550/M340 gates. The historical archive on the owner's wife's device must not be modified by these tests.
