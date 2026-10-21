# Android encrypted storage integration gate

The CI workflow **Waffra Android Encrypted Storage Integration** installs an app on
a disposable Android emulator and runs
`integration_test/encrypted_storage_android_test.dart`. It validates:
- Flutter + Dart native-assets hook packages SQLite3MultipleCiphers on Android;
- the `PRAGMA cipher` fail-closed check succeeds;
- the device secure storage returns the same key across opens;
- the database file does not begin with the unencrypted SQLite signature;
- a legacy snapshot can be staged and read again after reopening;
- the staging journal prevents duplicate inserts.

**Not covered by this test:** real user's SharedPreferences, final v1 relational
cutover, uninstallation/recovery, Android OS restore behaviour, iOS compilation,
concurrent writes, cross-device Firestore sync and PDPL compliance.

The workflow must not be used with a personally-owned production Android device:
`openShadow()` writes a test-only named shadow database and a random encryption
key into its app sandbox. The CI creates a clean emulator each run.

If this fails, do not enable migration/cutover. Keep the shipping app on its
current SharedPreferences ledger until a complete signed-off rollout.
