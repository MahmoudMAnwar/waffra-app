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
