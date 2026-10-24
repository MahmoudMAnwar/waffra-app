# M75 — Production financial writer inventory (partial, actionable)

This draft branch starts the final routing cutover after M74's four successful checks on SHA `29f8b356`. **It is not an activation flag.**

## Existing source routes

| Entrypoint | Today | Required encrypted release condition |
| --- | --- | --- |
| HomeScreen load / widget ledger refresh | `WaffraHomeFinancePersistence.loadWithWitness` → guarded legacy coordinator | Replace with independently verified SQLCipher source view; no SharedPreferences fallback |
| HomeScreen save, edits, batch clear, all-finance erase | `WaffraHomeFinancePersistence.saveLegacy` via queue and journal | Route to SQLCipher finance writer with the same generation/field-conflict semantics |
| Android widget confirmed SMS quick-add | `waffra_widget_capture.part.dart` → `withLegacyWriter` plus journal | Route confirmed entries, fingerprints and balance invalidation under one native source lock |
| SMS fingerprints | `main.dart` → `withLegacyWriter`; candidate `WaffraVerifiedEncryptedFinanceBridge.mergeConfirmedSmsHashes` | Preserve hashes from either engine and no raw SMS, no duplicate import |
| Categories and subcategories, deleted items, savings, recurring, challenges | App state → HomeScreen `persist()` | Atomic encrypted updates with read witnesses and no unrelated-field overwrite |
| Monthly budget and recurring reminder enabled setting | HomeScreen `persist()`/`withLegacyWriter` | Encrypted finance scalar and shared source lock; no stale preference edits |
| Custom savings-goal suggestions | Previously **direct SharedPreferences setStringList** from goal dialog | **M75:** moved to guarded lock through `WaffraHomeFinancePersistence.addCustomGoalSuggestion`, deduplicating against latest saved list |
| Receipt image capture | `main.dart.saveReceipt` → `getApplicationDocumentsDirectory()/receipts` file write | **BLOCKER:** write encrypted receipt BLOB only after transaction ID and same-source atomic commit; no plaintext photo temp or path fallback |
| Receipt viewer / PDF attachments | Legacy filesystem paths and home list | **BLOCKER:** use verified encrypted read gateway and refuse unknown owner/reference |
| Custom goal suggestions in SQLCipher | Restored in `fresh_finance_custom_goals` under M72 | **BLOCKER:** edit from screen through encrypted transaction after cutover |
| Backup/restore and permanent wipe | Existing legacy controls and protected backup | **BLOCKER:** source selector must ensure backup captures exactly one current source and receipts, with biometric, verified restore and rollback |
| Firebase cloud sync | Draft opt-in encrypted outbox / verified Firestore CAS | **BLOCKER:** end-to-end key recovery, encrypted record ID discovery, source activation and two-device reconciliation |

## Release gates

1. Every **live** finance writer and reader, including separate widget engine and receipt capture, chooses the same single source via one durable activation decision.
2. The source decision is validated inside the shared app/widget write lock and is **not** inferred from a keyfile alone.
3. Preflight must verify finance digest + custom-goal catalog + every physical receipt against staged encrypted rows; reject any intervening change and require restaging.
4. On any missing key, corrupted DB, conflicting marker, partial commit, or stale device operation, show a recovery state rather than a zero balance or writing to legacy.
5. No live migration, Firebase upload, activation flag or profile encryption key is enabled from this branch. PR stays draft.

## Next implementation priority

Convert the plain-file receipt capture and transaction-save boundary to a single, disposable-tested encrypted attachment/ledger commit; then wire the home/widget source-choice adapter. Continue with crash-cutover and recovery acceptance before release.

Existing Android unit/emulator green checks do **not** demonstrate live encrypted cutover unless the app/widget entrypoints above have been exercised on actual activated SQLCipher storage.
