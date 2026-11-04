# M353 — Pause/resume named budgets without changing historical transactions

**Feature status:** Draft PR #327. Not merged into main, not in a signed release, not yet verified by CI or Android device.

## Behavior

- Every previously created budget keeps its original ID, label, cap, category, alert threshold, and historical transaction references when paused.
- Old budgets without a `budgetActive` field load as active, so an in-place app update cannot silently pause pre-existing budgets. A present invalid activation field fails closed as paused.
- A selected named budget gets a compact adaptive switch, like the recurring-reminders switch, to pause/resume; user confirms the change. The picker and category view show a paused label. Paused budgets are not offered to new manual, SMS or OCR expenses, and budget-usage alerts are suppressed while paused.
- New expenses made during pause have a **null** budget link. Resume does **not** create an allocation, backdate a change, silently relink expenses, or double-post. Previously linked expenses retain their links even through repeated pause/resume cycles.
- Every unlinked expense shows a budget warning when viewing transaction details and a **Link to a budget** action. After selecting an active budget, a second confirmation changes only that existing entry's budget link and saves using the verified finance writer. User may cancel or leave records unassigned indefinitely.
- Editing an already-linked old transaction while its budget is paused preserves that existing link, and the picker labels it as paused. It cannot assign that paused budget to a newly created transaction.
- A budget selected during editing that is paused before confirmation must trigger an explicit warning and require re-selection (no silently dropped selection). SMS batch review also revalidates activation before posting.
- Deletion remains **different** from pause: delete drops the budget definition and links after confirmation, while pause never touches history.

## Regression/acceptance

1. M353 model tests: old JSON without active flag; paused flag persists; invalid flag fails closed; ID/cap/label/threshold unchanged; historical linked expense unaffected.
2. Save manual, OCR and bank expenses while budget inactive: no budget link. Resume: still unassigned. Viewing details: warning and action visible.
3. Existing entry whose budget was already linked before pause: still linked after pause and resume, with no duplicate financial expense.
4. UI tests cover the warning/link callback and paused old link; structural checks cover writer and active-only budget selectors.
5. Pause the budget while the entry and batch-review forms are open, confirm save: reject stale selection visibly; no silent data corruption.
6. Test write error and app cold restart: the state must be loaded from source of truth and no old finance records deleted.
7. Old APK ➜ signed new APK: verify in-place upgrade, previous manual transactions, encrypted SMS references, attachments, goals, recurring and budgets survive unchanged.

**Release NO-GO until:** exact-commit Flutter tests/analyzer pass, SQLCipher/legacy writer source integrity and backup/restore gates pass, signed Android in-place upgrade is tested against the previous version, and finance balances/receipt files are independently checked. Never uninstall the old app to work around a signing mismatch.
