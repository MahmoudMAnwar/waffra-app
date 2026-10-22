# M75 production finance routing audit

M75 is based on M74 SHA 29f8b356eb7bbf0436d01ad260c016074f146382.

- App startup and HomeScreen.load: source probe, ledger, categories, goals, recurring, challenges, recycle bins, budget.
- HomeScreen.persist: transaction saves/edits, categories, goals, recurring, challenges, budget and merchant rules.
- Widget capture: standalone startup, confirmed SMS, duplicate hashes, journaled ledger save.
- Deletions: transaction undo, delete all, category/goal/recurring recycle bins and full reset.
- Receipts: saveReceipt copies a file; showReceipt reads files; edit removes references.
- Backups: export and verified legacy restore.
- Widget balance: refreshWaffraHomeWidget displays the latest balance.

No production source switch, cloud sync or data migration is enabled.
The route inventory is a preflight for independent review only.
