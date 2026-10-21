# M32 — UI-compatible finance gateway over encrypted SQLite (inactive)

M31 provides transactional read/save operations for the three supporting finance modules and M29 for transaction CRUD. M32 unifies them behind a **single screen-facing gateway** whose JSON format matches existing Waffra models:

- MoneyEntry: id, title, category, amount in SAR, income flag, date, receiptPath
- BudgetCategory: same JSON used by the Categories screen
- SavingGoal: same JSON used by the Goals screen
- RecurringBill: same JSON used by the Recurring screen

Home/read code receives all four collections and income/expense totals from one injected SQLCipher vault. Results are checked against the exact integer-halala SQL totals. Updates for transactions, categories, goals, and recurring records are exposed through a common interface with explicit update-only semantics and validation.

## Current safety boundary

- The gateway is **disabled by default**, not imported or called by the running `main.dart`. This is the contract and tests for the upcoming UI cutover, not a claim that the shipped UI now reads SQLite.
- Individual collection read methods execute sequentially or via Future.wait; they are not yet a single consistent read transaction. Live cutover must use an app-wide read snapshot/barrier to avoid mixing successive writes.
- The legacy screen data contains more than four financial collections: challenge progress, category/goal/recurring 30-day trash, merchant categorization rules, delayed recurring events, monthly budgets, SMS dedupe hashes and other settings. These are intentionally **not** overwritten with empty arrays or implicitly migrated.
- Attachment-bearing transaction writes **fail closed**. Mapping or dropping old receipt paths would lose user data. M25–M27 tests are not an atomic multi-resource installer.
- SharedPreferences, Firebase, UI widgets, Android home-widget capture, notifications, exports and existing users remain unchanged.

## Next integration gates

1. Provide one cross-process finance source selector that locks/waits for Android quick-add and main-app writes, and survives cold-start interruption.
2. Implement backup/migration/rollback and 30-day recycle bin semantics for goals/categories/recurring; retain existing preference keys until verification.
3. Make all financial writes (including SMS dedupe, recurring execution, goal/category edits, bank SMS widget) go through the same repository once a fresh-install flag is active.
4. Switch `HomeScreen.load()/persist()` together—never one without the other—and verify UI/analytics/PDF parity and real Android cold reboot.
5. Keep Firebase authentication/sync activation last, outside offline storage readiness.

All M32 tests use disposable encrypted databases. No user account or live transaction data is changed.
