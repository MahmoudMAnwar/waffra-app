# M352 — Preservation of installed Waffra financial data across APK updates

**Release gate: BLOCKED until verified on a signed upgrade rehearsal.** The application must never delete a user's real manual transactions, bank imports, attachments, named budgets, goals, recurring schedules, or account information because the app version changed.

## Required upgrade behavior

1. Keep the same Android application ID (`com.waffra.app`) and signing certificate across both the installed and new APK. For an ordinary upgrade, install over the existing app, *never* uninstall first or clear app data. A signature/package mismatch is a blocking condition, not a reason to recommend uninstalling.
2. Before approving any candidate APK, provide users an optional independently stored encrypted `.waffra` backup, and validate restore separately with throwaway data. The existing export may **not include original receipt image bytes or all SMS fingerprints**: do not market that archive as a complete backup of every file until proved. Keep receipt originals and recovery routes independently protected.
3. Preserve raw `entries` and other legacy financial source keys during the initial transition. The source is still legacy SharedPreferences when the SQLCipher release gate refuses production activation. A failed import, missing key, invalid legacy row, or mismatch must **not** create a new empty ledger or silently clear the existing keys.
4. Every old `MoneyEntry` missing `budgetId` decodes with **null** linkage. Do not assign historical entries by inference. Existing IDs, full names, original amounts, income/expense flag, exact date, description, receipt association, merchant/source metadata and notes are unchanged.
5. After normal in-place upgrade, surface prior unassigned expenses in the Categories/Budgets UI for **opt-in, per-record** review. Show all existing budget options with category-based suggestions. The user may decline, choose a different budget, or postpone; after explicit confirmation only the existing transaction's budget link is changed. No new debit, bank post, duplicate transaction or changed category is allowed. Historical month totals stay in the original month.
6. Budget deletion must detach links but never delete, edit or rebook the expense itself. A failed budget-link write reloads the verified authority instead of claiming success. If a transaction changes during the dialogs, reject the stale confirmation.
7. Preserve all historical savings-goal `saved`, `target`, recurring active/day/startAt, category settings, deletion-bin content, and financial write provenance during **ordinary upgrade**. A user-triggered backup *restore* with its own documented reset semantics is different and must never be run automatically in an APK update.
8. Never auto-associate someone else's previous local guest ledger with the currently signed-in Google account, or upload legacy financial data to the cloud without a verified account-binding policy.

## Synthetic and on-device acceptance

- Run `test/m352_existing_data_upgrade_contract_test.dart`: old-format transactions, old goal savings, recurring obligations, category labels, pre-upgrade receipt references, immutable preference snapshots, and non-duplicating budget linkage.
- On a **consenting test phone with synthetic or independently backed-up data**, record the old binary's package ID, signing fingerprint, stored transaction count, income/expense total by original month, transaction ID set, goal savings, named-budget assignments and attachments. Install the intended signed release *over* the previous app, cold-start, compare the same invariants, and check an old entry's per-record budget review with Accept/Decline.
- Reopen the application and confirm the persisted link was saved once; test interruption or failed ledger save and verify no partial write.
- Verify receipts/photos can still be opened. The app's current portable backup alone must not be assumed to package those bytes.
- Do not perform the first upgrade validation on an irreplaceable family member's phone. Keep old APK, original local data and an independent backup recoverable until all upgrade and rollback checks have passed.

**NO GO:** changed app ID or signing cert, unexpected login/account switch, missing/changed transaction or attachment, missing savings/recurring data, unmatched counts/sums, source migrated without read/write parity, corrupted source that was silently replaced, or any auto-linked/duplicated historical expense.

This is a release acceptance contract and a draft regression test, **not proof that real-device upgrade QA has passed**.
