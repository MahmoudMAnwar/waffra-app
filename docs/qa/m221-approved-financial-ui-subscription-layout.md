# M221 — Approved financial UI updates

This branch changes the real Waffra app UI, not just mockup images.

## Approved, implemented
- Categories: main and subcategory counters side by side at top, a bounded compact red "Deleted categories (N)" control directly underneath, and an "Added by me" filter that composes with income/expense, budget and search.
- The category data model now stores an explicit `origin` value: `user` for manual category creation; `detected` for data explicitly marked as such; otherwise `system`. Edits preserve origin. Legacy categories with no origin remain `system` to avoid incorrectly claiming manual provenance. Historical manual categories cannot be reliably reclassified without verified migration evidence.
- Savings goals: current count and deleted goals button share one row.
- Recurring: calendar and deleted recurring controls share the upper row; a bordered recurring count and reminders switch share the next.
- All shared deleted-item buttons use compact uniform minimum height (52 logical px), preserved red tone, English/Arabic labels and adaptive theme styling.
- Circular FAB uses one `HapticFeedback.lightImpact()` synchronously on an accepted tap; unchanged fixed physical-left Arabic/physical-right English anchor, no haptic on tab changes.
- Account > Financial tools > Subscription insights: an original RTL/English premium green summary, actual monthly and annual estimate, live detected candidate list, confirmed schedules and informative empty states. Review & add invokes the existing validated recurring editor with pre-filled suggestion; Ignore hides a candidate **only for this view session**. No synthetic service names or invented amounts are shown to users.

## Limits, evidence and release
- No bank integration, SMS permission escalation, source switch, or privacy weakening.
- Subscription suggestions are estimates from already recorded local transactions, not confirmed third-party contracts.
- Candidates must be confirmed in the recurring form before a schedule is stored.
- Haptics depend on OS/device vibration settings; physical device response remains unverified.
- SQLCipher production activation stays **NO-GO**. No independent proof yet of 24 authenticated live routes, account-owner key enrollment, receipt byte parity, cross-device backup/restore or two physical Android phones. This PR must not be mistaken for a production-certified APK.
- The next signed APK must originate from a fully tested final main commit **after** all release gates pass, not from this draft feature branch.
