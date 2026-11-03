# M414 – Android notification and cold-restart acceptance

Target: PR #348 on its **exact reviewed HEAD**, never the already merged main APK.

## Ground truth
- A goal has an optional milestone percentage only when its target is positive. Open-ended savings never show a progress-percent notification.
- A recurring entry's **reminder** switch and the global reminders switch govern only notification scheduling; the entry's **active** financial rule is independent. Pausing a recurring financial entry keeps its own reminder preference.
- Main and subcategories classify posted entries. They have no spending cap and may not inherit a named-budget percent alert.
- Goal milestone and budget threshold notifications originate from **confirmed in-app events**. Waffra does not subscribe to or monitor bank transactions while force-stopped.
- Android notification permission is requested when a relevant alert or recurring reminder is enabled. Denied permission must not block saving financial data.

## Mandatory signed-Android device matrix (not satisfied by CI)
1. Android 13+ with notifications allowed: create a fixed 1,000 goal, enable 50% and fund 490 then 20. Exactly one progress alert at the configured threshold. Repeat a save above 50%; no duplicate stage warning.
2. Create an open-ended goal, contribute repeatedly, and reopen after force-close. No percentage selector or progress alert. Savings history and wallet totals remain unchanged.
3. Create a fixed goal with the alert OFF; fund past threshold. No notification. Re-enable at 75% and test a **new crossing**; no retroactive event when simply toggling.
4. For a recurring expense, switch its **reminder OFF** with the global reminder switch ON; confirm the same future obligation exists, still active, same amount/date. Switch reminder ON and verify its scheduled due reminder. Pause the financial entry and verify the reminder preference remains saved, without scheduled delivery while paused.
5. Force-close and relaunch. Verify the goal alert percentage, both goal and recurring switches, and the global reminder switch. Confirm previous transactions, links and balances do not change.
6. Deny notifications in Android settings. Saving a goal/recurring entry still works; no false "delivered" UI. Allow permission again, reschedule, then verify notifications on the actual device.
7. Validate recurrence reminders one day before due at 09:00 **device local time**, including month-end and DST. Verify reboot behavior and app process termination in a test environment.
8. Trigger confirmed manual and SMS budget expenses with budget alerts configured to 50%, 75%, off, and paused. Verify only applicable warnings; no spurious historical import alerts. OCR must only trigger after user confirms a posted expense.
9. Repeat in Arabic and English, light/dark mode, and Android with gesture navigation and three-button navigation.

## Required evidence
Record device model, Android version, app build/version, exact commit SHA, notification permission state, trigger transaction/goal ID (synthetic data), expected/actual outcome, screenshots of settings + system tray, and pass/fail. Do not record real bank identifiers or personal SMS content.

**Release gate:** CI test pass does not replace tests on a physical Android device. Do not mark this item passed or merge PR #348 without the evidence.
