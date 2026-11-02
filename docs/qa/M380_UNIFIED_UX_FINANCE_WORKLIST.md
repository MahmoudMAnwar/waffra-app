# M380-Waffra consolidated UX + financial safety worklist
Status: in progress; approved requirements; no claims of completion.
Branch: feature/m380-unified-ux-business-20261102
Base: main 5f6b35cd82f475f45dc06004d3c77197a4cedd08
No main edits, no APK, no production SQLCipher cutover.

## UX checklist
01. [ ] BUG-01 Budget modal reopen must not show grey/error body.
02. [ ] IMP-02 Add budget button spacing.
03. [ ] IMP-03 Saved budget cards collapse/expand; show details and quick actions only when open.
04. [ ] IMP-04 Organize and expand suggested budget templates independent of category hierarchy.
05. [ ] IMP-05 Suggested budget list collapsible.
06. [ ] IMP-06 Saved-by-user / suggested / all budget filters.
07. [ ] IMP-07 Shared '+' FAB blur/dim underlying page.
08. [ ] BUG-08 Goals and recurring '+' changes to '×' and shows short action menu.
09. [ ] IMP-09 Remove repeated selected budget name in Home.
10. [ ] IMP-10 All editable forms keyboard Next/Done focus traversal and auto-scroll, including SMS/OCR.
11. [ ] IMP-11 Calendar Today next to month arrows, outlined month/year picker, RTL/LTR.
12. [ ] IMP-12 Centered green-bordered searchable blur backdrop dropdowns throughout app.
13. [ ] IMP-13 Copy current/previous goal or recurring into NEW record with independent IDs, no copied savings/payments.
14. [ ] IMP-14 Compact edit/delete and green/gray active switch for budget/goal/recurring cards.
15. [ ] IMP-15 Every INTERACTIVE control has visible bounded tap affordance; plain labels stay plain.
16. [ ] IMP-16 Category quick actions compact border/no black lines; pause/resume without altering old transactions.
17. [ ] IMP-17 Goals wallet balance hero identical geometry to Home spendable balance card.
18. [ ] IMP-18 Uniform budget picker and pre-save OPTIONAL budget link confirmation; manage/create from picker, historical relink without new charge.
19. [ ] IMP-19 Remove genuinely redundant visible text, retain financial/permission/security warnings.
20. [ ] IMP-20 Nested Back/Android gesture restores previous step and draft, prompts before discarding.

## Business and release safety gates
01. [ ] Goal wallet transfer / explicit source accounting with zero double-debit.
02. [ ] Strict idempotency on manual SMS OCR recurring and goal due posting.
03. [ ] Original FX currency, accepted rate, timestamp and exact minor units; no historical repricing.
04. [ ] Paused categories, budgets, goals, recurring preserve historical links and values.
05. [ ] Refunds/chargebacks and own-account transfers distinct from ordinary income/expense.
06. [ ] Separate total monthly ledger expenses from named-budget-linked expenses.
07. [ ] Backup restore actual receipt bytes + SMS dedupe metadata, tested before release claims.
08. [ ] Signed same-app upgrade preserves financial records; rollback and failure never clear old data.
09. [ ] Staged SQLCipher production activation stays OFF until device, backup and migration approvals.
10. [ ] Final one PR only when all changes integrated, CI green on exact head, Android RTL/LTR manual QA.

## First implementation group
- Remove black default ExpansionTile dividers in quick actions, and outline tap surfaces.
- Compact action controls but preserve minimum 48dp tap targets.
- Saved budget card collapse + creation spacing; preserve financial source.
- Targeted tests. All work remains unmerged until single final PR is approved. 
