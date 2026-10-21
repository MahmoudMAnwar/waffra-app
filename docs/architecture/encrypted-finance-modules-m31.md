# M31 — Category, goal and recurring screen-model persistence

This stacked experimental PR makes the three main Waffra finance modules useable via an opt-in encrypted-SQLite repository, without modifying any running finance screen or legacy preference.

- Each module can **create**, **load**, and **update** its existing JSON-shaped records in SQLCipher, preserving ID, Arabic/English names and the additional fields used by Waffra UI.
- Money amounts are checked as exact integer halalas before saving.
- Missing IDs/titles, malformed dates, bad recurrence days, invalid budgets, duplicates and unauthorized updates fail with an exception.
- Every write uses an SQLite transaction; records survive database cold reopen.
- **Delete is blocked** deliberately: goals require the already approved 30-day recycle bin, linked-goal warnings and zeroed restored allocations; category and recurring removals need historical linkage/recovery. The new repository must not silently bypass those rules.
- An absent initialization marker, unknown schema, import sandbox or default-off switch prevents access.

## Not active in live Waffra

The current app's main.dart, widgets, SMS capture, goals and reports still use SharedPreferences. This implementation prepares the SQL API for those screen types but does not yet redirect their UI. Enabling parallel writers would corrupt data, so a single-writer source selection and receipt rollback are prerequisites. Firebase remains last; no bank account integration is introduced.
