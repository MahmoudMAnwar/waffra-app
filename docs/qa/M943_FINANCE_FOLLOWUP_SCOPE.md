# M943 / Issue #651 — finance follow-up to M942

Date 2026-11-14. This Draft PR is stacked on `fix/m942-bank-opening-balance-dropdowns-20261114` (#650), not directly on main; never merge out of order. Owner requirements total **8**.

| # | User-approved objective | Status | Acceptance |
|---|---|---|---|
| 1 | Do not display historical income/expense fallback as verified bank balance when SQLCipher unavailable | Code committed; CI pending | Unverified Home header shows a placeholder, not 0 or old net; verified zero account is real 0 |
| 2 | Bound Home rendering/pagination for thousands of operations | Collapsed Home page bounded; expanded still needs device profiling | Count and page without all-result list; preserve exact stable date ordering and filters |
| 3 | Remove inverted / unauthenticated month comparison | Code committed; CI pending | No percentage until independently verified historical opening/closing balances exist |
| 4 | Recognize Saudi catalog bank/wallet sender identities safely | Code committed; CI pending | Exact tests for every approved provider, false positives rejected, never auto-post without user approval |
| 5 | Distinguish custom “other” institution children without cross-bank merging | Code committed; CI pending | Persisted and reopen-safe explicit relationship only; no inferred ownership |
| 6 | Permit explicit clearing of saved account suffix | Code committed; CI pending | Atomic SQLCipher delete + rename, user approval, stale witness check |
| 7 | Old V24/V3 backup parity and reconciliation | Synthetic V3 checks added; real owner archive untested | Synthetic regression and original device archive evidence tracked separately |
| 8 | Remove dead AI compatibility code where safe | Retired-runtime audit tested; old safety helpers intentionally retained | Confirm runtime graph and keep currency/source negative-security tests; no claims about removed files until validated |

**Invariant:** no unreviewed money write, no SMS auto-post, no account/provider forgery, no changing +/Snackbar/layout, no weakening M385/M550/M340 gates. The historical archive on the owner's wife's device must not be modified by these tests.

## Implementation review (code committed, not a release certificate)
- `lib/waffra_home_balance_header.part.dart`: nonnumeric `—` when the authenticated account projection is unavailable; no bank-zero masquerade.
- `lib/waffra_finance_period_index.part.dart` + Dashboard: allocation-free count and bounded first-page read with exact chronological order; user-expanded all-history render needs physical Android load test.
- M943 bank SMS sender aliases for each of the 17 catalog providers, with explicit wallet-vs-bank classification and no implicit financial transaction save.
- `fresh_finance_custom_institution_links`: explicit root ID, no same-name guesses, type/provider/source checks, verified account projection and optional encrypted V3 archive extension. Existing old V3 archives without this field remain accepted.
- Verified bank suffix clear: explicit UI opt-in, same SQLCipher writer for account rename+remove, no balance/ledger change.
- Old V24/V3 device backup and physical Android screenshot/latency checks **not performed**. Retired AI compatibility files remain only for negative/security regression until removal proven safe; no live Qwen/cloud SMS path introduced.
- This stacked PR must be reconciled after #650 and #648 and latest exact-head CI must pass before merge.
