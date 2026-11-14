# M940 / M941 — تحسين الأداء واستكمال هيكلة وفرة

Owner approved 2026-11-14: [#646](https://github.com/MahmoudMAnwar/waffra-app/issues/646) + [#647](https://github.com/MahmoudMAnwar/waffra-app/issues/647). One Draft PR for items 2 and 3.

## Before / target
The dashboard re-sorts all scoped MoneyEntry records on every unrelated widget rebuild. The income/expense summary also sorts again. The Home State keeps the period-index cache and filtering rules.

The approved code change reuses ONE date-descending immutable ledger index per hydrated verified finance revision; exact source-backed account entry-ID filtering, read-only bounded pages, and extraction of query policy and index lifetime from Home State. Keep every existing invalidation (insert/edit/delete, restore/reset, reload), money source, SQLCipher authorities and financial calculations unchanged.

## Acceptance and limits
- Regression must exercise 2,500+ synthetic entries, all page boundaries without duplicates, equal-date ties, immutable snapshots, different verified account scopes, search/date/type/amount/category, cache invalidation, existing M684/M810 tests and full Flutter CI.
- Preserve the user-approved Home/Goals/Recurring designs, the static 58dp + FAB, Snackbar and Arabic/English directionality. Do not change database writers, permissions, backup format, account linking or messages.
- CI host measurements are not a real-phone measurement. Signed-APK cold/warm startup, 2,000+ transaction DB profile, memory/jank and old archive parity on disposable Android are separate **Pending** items.
- In-memory paging does NOT claim a SQLCipher `LIMIT/OFFSET` or keyset-paginated persistent repository; that would need a separately verified authenticated storage query and regression matrix.

## M940 SMS review paging
The native owner-verified candidate queue is still scanned/grouped completely, without deleting any rows. When browsing a sender, the Flutter list initially exposes 100 message cards and reveals more in bounded 100-row windows on near-bottom vertical scrolling; the original `visibleIds()` remains the complete sender group for select-all and batch exclusion, including messages past the rendered window. No UI card styling, sender group order, original SMS text, native scan or finance confirmation changes. Host regression uses 2,400 message IDs. This is **presentation pagination only**; true native database cursor paging and measured Android frame stability remain pending real device work.

## M486 regression protection during incremental scroll

Exact full-suite CI at SHA 987e677 exposed one failure in `test/m486_sms_back_navigation_source_test.dart`: the original sender sheet explicitly forbids `WidgetsBinding.instance.addPostFrameCallback` anywhere in the picker, since that API previously broke nested editor navigation. M940 now coalesces near-bottom notifications into a zero-delay **event-loop turn**, guards the original selected sender ID and mounted picker context, and leaves nested review/editor routing untouched. The original M486 negative regression stays enabled and unchanged. Full CI must be repeated on this commit.
