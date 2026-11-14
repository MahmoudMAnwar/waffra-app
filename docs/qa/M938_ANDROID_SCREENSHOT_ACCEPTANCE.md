# M938 — Android screenshots: Snackbar, goal/due filters and secure restore

Issue [#643](https://github.com/MahmoudMAnwar/waffra-app/issues/643) · Same [Draft PR #640](https://github.com/MahmoudMAnwar/waffra-app/pull/640)

**Status: Implementation added; exact PR HEAD tests and real Android approval pending.**

## Screenshot issues and acceptance

1. **Restored notice placement:** from the account/settings Restore dialog, select an encrypted `.waffra` file, enter password, authorize replacement; the success Snackbar must emerge from Home's fixed anchored presenter. For Arabic (FAB on left), the notice starts at FAB's right edge; for English, its right edge stops before the FAB on the right. Long two- and three-line notices grow UP, with no motion/overlap of the global 58dp +. Same rule on Goals and Due tabs. Preserve dismiss-on-tap, current border/stripe/palette and independent footer height.
2. **Goals:** the count badge gives the overall total. Funnel contains *all*, active, inactive, completed, incomplete, this week and this month, all with counts from the current verified goal list, not from dummy data or a stale filtered subset. Date-window checks use local DateUtils.dateOnly and no future date inventions. The existing More icon is three dots; its menu opens Deleted Goals and shows inactive/incomplete shortcuts. Current goal cards, amounts, layout and funds remain unchanged.
3. **Due/Recurring:** funnel owns all/today/week/month/overdue/active/inactive with counts. Keep the separate three-dot More actions for deleted recurring and reminders. Check on Android with narrow screen and 200% font for horizontal overflow.
4. **Deleted goals:** an older authenticated V24 encrypted restore might contain old goal-trash JSON but zero new typed SQL tombstone rows. Clicking Deleted Goals may offer **explicit one-time repair of the missing index** rather than a generic source error. Owner consent and verified exact SQLCipher baseline are mandatory. Repair must refuse mixed/partial SQL metadata, forged duplicates, future/invalid dates, active IDs and stale generations. It inserts only source-stamped/hash checked 30-day metadata; actual restoration still uses the verified module writer, resets old goal savings to zero and never mutates historical transactions or bank accounts.
5. **Backup dialog:** no Advanced Options/clipboard import; `.waffra` file picker and original archive password retained. There is *one* fingerprint prompt when opening the secure backup menu; no second prompt from the same modal after entering password. The destructive replace question, source witness, SHA, SQLCipher preflight, authentication, rollback and missing-receipt warning all remain.

## Testing and reporting

- Synthetic storage test: `test/storage/m938_legacy_goal_recycle_repair_test.dart`. Reconcile old tombstone metadata with source digest unchanged, reject unapproved/stale/partial repair, restore goal without changing entry ledger.
- UI/source tests: `test/m938_goals_restore_fab_contract_test.dart` and existing M668/M671/M675 notice tests.
- On the disposable Android phone, verify one/multiple-line real toast geometry, all count filters, the three-dot goal menu, restore dialog OS biometric count, a previously authenticated legacy backup and Goals trash after app restart.
- **No-go** if duplicated entries, missing goals, wrong totals, stale typed SQL witness, an unexpected second OS fingerprint, fullscreen notice covering FAB or any data loss. Do not update spouse phone before independent finance acceptance.

No actual personal backup, password, SMS body or private screenshot was uploaded by this implementation.

## M939 — owner exact-edge clarification for Snackbar (same Draft #640)

On all plus-button routes, the Snackbar's entire visible card including unused blank space ends **exactly** at the near physical edge of the unchanged 58dp + circle. It does not overlap or leave the old 8dp gap. Two-/multi-line messages expand upward with stationary bottom and fixed horizontal bounds. Arabic plus is physical left, English physical right. In Settings, Tools, and account detail routes without a plus, the card extends horizontally from 12dp left margin to 12dp right margin, even for short labels, with original bottom/footer clearance. The shared notice presenter and tap-to-dismiss are unchanged. Geometry widget regressions verify edge equality and wrapping; Android screenshot acceptance remains outstanding. M163 old source expectation now uses the mandatory once-on-dialog-entry fingerprint and verifies reminders after the correct durable restore write.

### M939 follow-up: exact-HEAD failure root cause

Flutter captured four M675/M938 notice failures on the first M939 SHA. Two M675 tests still demanded the now-retired 7dp gap. More importantly, the anchored FAB notice host centered its content in an oversized available-height box; when a message wrapped, its lower edge moved instead of remaining fixed. The genuine host layout is corrected to shrink-wrap height with Center(heightFactor: 1.0), retaining the existing 58dp composited target and the current long-message assertions. Original M938 bottom-invariance tests are intentionally NOT relaxed. M675 checks now demand exact touching edges, without overlap. Recheck latest-SHA Flutter and actual Android before acceptance.
