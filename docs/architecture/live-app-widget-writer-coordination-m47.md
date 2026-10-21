# M47 — Real dashboard + widget finance write coordination (legacy safety)

Waffra's current live HomeScreen and separate Android widget still write SharedPreferences. Their prior independent transaction writes could overlap and lose newer SMS entries. This stage improves **the running legacy code**, without pretending that production encrypted cutover is finished.

## Changed actual app routes

- Both dashboard `persist()` and the quick-add widget's whole read/dedupe/write sequence now participate in the same app-private, advisory operating-system file lock.
- Before each callback, re-read native SharedPreferences and reject any pending/active encrypted cutover evidence (M43).
- HomeScreen `persist()` refuses overwriting a newer widget transaction revision; the UI must reload/retry after such a conflict.
- Widget saves the transaction list, SMS deduplication hashes and widget last-save revision while holding the same lock; only actual persisted records count as success.
- All standalone app bank-SMS hash writes now merge with the current saved hashes under the writer lock, rather than clobbering hashes created by the widget.
- Delete-all checks that the widget did not write a newer transaction between user confirmation and actual deletion and uses the shared writer lock.
- A dedicated concurrency suite checks overlapping writer callbacks, the latest merged view, interrupted writer cleanup, and marker protection.

## Limitations and release gates

SharedPreferences provides **no atomic multi-key transaction**. An OS kill after saving `entries` and before saving SMS hashes still requires a durable journal/replay or a source switch to SQLCipher. Any other legacy writer that does not use the coordinator remains a possible conflict; this is only a safe bridge while live-cutover integration is being finished.

The new SQLCipher UI patch service from M46 remains disabled for live users. We have not modified Firebase, account login, real user finance data, nor replaced the application source. The next work must route all finance readers/writers, including reminders, imports, receipts, reports and the widget, through a verified single encrypted source; only then activate markers and build a release candidate.
