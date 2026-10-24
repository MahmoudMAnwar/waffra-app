# M176 — explicit finance module intents, no SQLCipher activation

After M175 split manual transaction, deletion/undo and recurring payment
posting routes, M176 extends the **same guarded authority** to live module
mutations that previously called `persist()` with an anonymous
`transactionEdit` route. Every existing call now declares its intent.

## Changes and reviewed counts

| Module | Live Home callsites | Other source |
|---|---:|---|
| Category add/edit/delete/restore, trash expiry and category selection-sheet creation | 10 | — |
| Saving goal add/fund/delete/restore, trash expiry | 6 | — |
| Recurring create, enable/disable and delete | 3 | 3 recurring-trash expiry/restore/permanent-delete |
| Monthly budget and savings challenges (create/complete/remove) | 4 | — |

`persist(route:...)` still freezes the **same immutable finance snapshot**,
retains the screen-read source baseline and uses the cross-engine write queue.
The existing legacy backend remains authoritative. Unsupported SQLCipher
module routes fail closed through `WaffraVerifiedFinanceAuthority` and never
silently inherit approval for another route.

M176 does **not** claim all live routes are converted, attempt migration,
create a key, switch source markers, enable SQLCipher or deploy Firebase.
The tests exercise the intended route signatures and fail-closed conditions,
not user financial records. Historical transactions, receipts and budget
values are not changed by this PR.

## Next production blockers (independent of green CI)

- The catalog v2/v3 initialization and custom goal suggestions still use
  guarded legacy writers directly; `recurringRemindersEnabled` and the
  SMS dedupe-hash fallback also need source-aware route refactors.
- Finance deletion/reset, receipt bytes, source activation and backup restore
  need atomic SQL-only writers and verified app/Widget cross-engine behavior.
- 24/24 signed-off routes, encrypted key-loss recovery, non-empty historical
  migration, crash rollback, two real-device restore tests, public deletion/
  privacy URLs, Play signing and explicit release approval remain NO-GO.

This step makes unsupported finance actions *visible and blockable* during
future rollout; it does not turn them into verified encrypted writers.
