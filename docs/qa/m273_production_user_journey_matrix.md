# M273 — Production user-journey regression gate

This suite complements Waffra's existing Flutter, storage, Android, PDF and encryption tests. All records are synthetic and local. The gate runs automatically whenever CI invokes `flutter test` (as it already does before publishing a signed APK).

## Priority 0: prevent incorrect balances and lost user information

- Bank paste previews: fresh vs repeated-in-batch vs already-saved messages.
- Reject OTP/failed transaction notices from the confirmed ledger.
- Validate that a batch of **100** messages remains intact and that the actual confirmation path refuses **more than 100** without truncating.
- Incoming credits versus credit-card expenses with distinct direction, correct amount, and unrelated balance lines.
- Date validation rejects impossible leap days and invalid 24-hour times.
- Transaction JSON round-trip preserves original notes, receipt paths, date, merchant, ID and amount.
- Legacy messages with previously saved long titles/notes do not block unrelated edits, but revised invalid-length text is rejected.
- Language and nominal presentation-country switches do **not** silently run FX or change stored money.
- Exact halala accounting across several small incoming and outgoing amounts.

## Priority 1: avoid disruptive UI and edge-case bugs

- Next payday handles leap February and calendar rollover.
- Recurring monthly day 31 safely clamps into shorter months, excludes income and blocks already-paid items.
- Suspicious duplicate detection avoids incoming transfers and historical unrelated expenses.
- Expense grouping uses an inclusive start / exclusive end time window.
- On-screen balance hide toggling conceals the actual number **and** the currency artwork.

## Future end-to-end acceptance beyond this deterministic pack

- On a real running app, follow Add → Confirm → Home → Edit → Relaunch → Delete/Undo; assert final ledger and Widget totals.
- Exercise paste of 100 SMS, cancel mid-save, background/resume, and retries after a rejected write; capture the exact UI state.
- Render both PDF exports at different device sizes, open them and verify every table cell and original Riyal mark in Arabic vs SAR in English.
- Validate backups by closing/reopening the running app; check both valid restore and refusal of corrupted/wrong-password restores.
- Golden screenshot comparison at 320px–tablet, 200% text scale, Arabic RTL/English LTR and light/dark appearance.
- Stress rapid taps and back navigation with animation in progress, and pull-to-refresh after loss of connectivity.

## CI acceptance

P0 test failures must block the main APK release. The established signed release workflow already runs all Flutter tests and fails closed on unsuccessful checks. This PR adds tests only; it does not change financial or release runtime behavior, nor falsely claim end-to-end device verification.
