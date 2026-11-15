# M1000 — Financial trust and control (Issue #710 / Draft PR #711)

**Owner workflow:** code implementation now, NO manual tests and NO new test files until owner explicitly starts the QA phase. GitHub's repository-owned automatic CI may trigger on pushes; that is not certification. Do not merge this Draft without later QA.

| # | Owner-approved enhancement | Source work in this Draft | Status |
|---|---|---|---|
| 1 | Read-only balance integrity center | Independent SQLCipher account reconstruction and source-witnessed page, no balance mutation | Code implemented; **not tested** |
| 2 | Backup preflight and preview | V24/V3 authenticated archive summary, duplicate IDs, date bounds, receipt/account counts and before-vs-after restored ledger preview | Code implemented; **not tested** |
| 3 | Durable finance change history | Read-only before/after financial comparison is implemented for backup review. No durable, append-only edit/delete audit is claimed. | **Partial** |
| 4 | Large-history performance | Reuse current SQLCipher verified keyset pagination; new filters apply before LIMIT, 50-entry pages. No large-device profiling. | **Partial** |
| 5 | Search and unified filters | Account, income/expense, title/merchant text, category text, date range, exact SAR amount bounds inside verified SQL query | Code implemented in account transactions; **not tested** |
| 6 | Recurring and due duplicate detection | Bounded read-only same-account/same-schedule-day/amount/title advisories, never auto-delete, no ledger charges | **Partial**, account-linked recurring only |
| 7 | Projected liquidity | Active scheduled recurring account-linked dues projected in integer SAR halalas, independent of actual cash; no due marked paid | **Partial**, missing other due kinds |
| 8 | Accessibility/RTL stability | Localized trust screen, semantics for statuses, existing FAB/Snackbar/navigation untouched | **Partial**, full-app review not done |

## Safety
- SQLCipher source authority and verified-bridge lock only; no second finance writer.
- Restores still require password authentication, biometric, isolated SQLCipher candidate, V3 history parity and owner confirmation.
- Existing legacy backup, account schema, bank SMS, transactions and goal wallet behavior not migrated by this Draft.
- Never infer account ownership or change money silently. Source differences are warnings, never repair commands.
- Android physical-device, legacy spouse archive, real SMS, RTL and startup timings have NOT been validated.

## Planned next code work (still before QA)
- Durable encrypted append-only audit for edits, deletions and undo under a verified single-writer transaction, with owner-scoped history UI.
- Broader recurring/goal due presentation tied to verified source rather than detached copies.
- Profile large histories before claiming the actual performance gain.
- Improve the source and message lifecycle interactions after code review.

**Exit criteria for code-only stage:** all eight rows show implemented-in-source, then hand over to owner for an explicitly separate QA phase. Current Draft is **not** 8/8 complete.
