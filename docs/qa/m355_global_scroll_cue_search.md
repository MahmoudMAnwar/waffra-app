# M355 — Discoverable scrolling and unified in-list search

**Scope:** Draft PR #327; not yet on main or in a production APK.

## User issue and implementation
People opening a long list or screen sometimes cannot tell there are more entries below the current viewport, especially in Android transaction editors, category/budget selection dialogs, and smaller phones.

- At the MaterialApp root, `WaffraVisibleScrollBehavior` adds a consistent small emerald/green position cue to every **vertical Scrollable** on Android/iOS/Fuchsia: main pages (transactions/goals/recurring/categories), selection dialogs, details and manual/SMS/OCR forms. Existing Material desktop draggable scrollbars remain as-is.
- `WaffraOverflowScrollCue` listens for `ScrollMetricsNotification` on initial layout and resize and for `ScrollNotification` during swipes. Shows the thumb only if content exceeds its viewport. Its thumb size indicates visible fraction; its position follows scroll progress.
- It is deliberately **noninteractive**, using `IgnorePointer`. People scroll by the existing swipe/scroll gesture, without stealing taps, changing physics, scroll offset, content size, or touching the finance ledger. Don't mistake the decorative cue for a draggable desktop scrollbar.
- Handles nested scrollables via `notification.depth == 0`, horizontal content via the default behavior, unbounded/nonfinite metrics by hiding rather than throwing, and both right-to-left and left-to-right via `PositionedDirectional(end:2)`. Does not reveal an extra cue for lists whose full contents fit.
- Currency/category/transaction search already uses `waffraSearchAny` and unified spelling normalization. Added the same search to historic unlinked expenses and their budget options, and added a search action in the shared manual/bank SMS/OCR entry editor's budget selection.
- The native Flutter `DropdownButton` overlay is not a normal app-owned Scrollable and may not show this custom scrollbar. Large budget dropdowns now use `menuMaxHeight` within the screen and have a separate searchable picker for the transaction editor. Small finite dropdowns do not need a cue.
- Search/filter is **read-only**, never rewriting Arabic source labels, category IDs, amounts, dates, encrypted messages or stored transactions.

## Acceptance
1. `test/m355_global_scroll_cue_search_test.dart` verifies overflow cue appears before first scroll, moves after scrolling, hides for nonoverflowing and horizontal lists, does not intercept taps, matches Arabic spelling variants and English case, and is installed at the app root.
2. QA on small and large physical Android phones using three-button and gesture navigation; Arabic RTL and English LTR; font scaling; light/dark; accessibility/VoiceOver/TalkBack; scrolling while typing/searching with keyboard open; nested dialogs, transactions, SMS/OCR, goals, recurring, backup dialogs, categories and budget list.
3. No runaway rebuilds, scroll jank, off-screen action buttons, RenderFlex overflow, loss of scroll position, unexpected double scrollbars, or changes in finance totals.
4. CI and signed in-place upgrade/device acceptance required before main or user APK. **No real user data has been inspected or changed.**

Known limitation: a visual scroll-position cue indicates more content and supports touch scrolling; it is not itself a thumb users can drag. Native desktop scrollbars remain interactive.
