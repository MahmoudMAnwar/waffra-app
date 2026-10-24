# M50 — Deterministic widget SMS UI regression without disabling production locking

The full Flutter UI workflow was timing out for 10 minutes at `Only confirmation writes an SMS transaction and prevents duplicates`. The test called the production native `File.lock` callback from Flutter widget-test's `FakeAsync` environment. Native file I/O cannot reliably progress under that synthetic clock.

## Fix

- Allow **only explicitly injected widget tests with a disposable test directory** to bypass native file locks while still using real mock SharedPreferences, source-marker validation and actual widget confirmation parsing/save/UI code.
- Production `WaffraWidgetCaptureApp()` retains its original default (`testBypassNativeLock=false`): the same OS file lock and latest-preferences refresh continue to protect actual Waffra.
- Replace the widget test's real-time polling loop with fake-clock frames and assert that the confirmed entry is really present. The separate `live_legacy_finance_writer_coordinator_test.dart` and `experimental_writer_gate_test.dart` still exercise real OS file lock serialization and failure release.

## Scope

This is a test-harness stabilization, not an encrypted cutover or release. Continue to run complete Flutter and Android CI. The production app and widget still require coordinated source migration, finance backup/recovery, receipt migration and final APK acceptance. Firebase remains unchanged.
