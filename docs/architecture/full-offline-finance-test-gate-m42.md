# M42 — Final pre-cutover Flutter UI and finance CI gate

Adds a Pull Request GitHub Actions job that runs **all existing Flutter unit and widget tests** in the repo, not just the new encrypted-storage synthetic device tests:

- Strict Dart analysis on all storage modules and storage tests.
- Whole-app Flutter static analysis.
- Every test in the test/ folder using Flutter's test runner: transaction parser and validation, bank SMS and quick-add widget UI, 100-message confirmation rules, Arabic/English and RTL/dialog behavior, onboarding and theme, Tajawal, recurring policy, protected backup and reports, visual behavior and finance storage tests.
- Explicitly inspects whether the real HomeScreen and Android quick-add still write legacy SharedPreferences, and verifies new writer and receipt components are default-disabled. This allows the audit to report **NOT YET CUT OVER** rather than claiming finance migration is complete.

The separate Android emulator pipeline runs M40 and M41 encrypted finance tests, including 100 SMS records, 20 concurrent app/widget-style appends, goal restore, receipt BLOBs and cold reopen.

## Release criteria not yet demonstrated

Passing both CI pipelines proves test-covered code *works in synthetic tests*, not that:
- real HomeScreen/Widget/recurring/goal/trash/SMS/pdf/analytics routes are fully connected to encrypted finance;
- the migration marker write is durable and recoverable;
- older user data and all receipt files have been migrated;
- user APK with all features was installed and manually validated;
- Firebase login/sync has been configured.

Do **not** merge all stacked draft PRs or publish release solely on this CI. Complete production routing, migration/rollback, Android app startup and release APK verification, and user acceptance testing before release. Firebase is deliberately last.
