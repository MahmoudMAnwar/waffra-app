# M23 — Android isolated end-to-end recovery verification

Before Firebase setup, the non-cloud encrypted migration stack should be exercised inside the Android OS rather than only host Dart tests.

## CI changes
`.github/workflows/storage-android-integration.yml` now runs an additional Android emulator integration test (`integration_test/offline_restore_android_test.dart`), after the existing device encrypted-vault smoke test. Static Dart analyzer covers both test files.

The test explicitly uses a temporary app-private directory and a separate encrypted database and journal. It creates a password-encrypted archive containing income, expense, and receipt bytes; runs the combined receipt/finance parity and ordered journal checks; checks files were saved byte-for-byte, that the DB is ciphertext at rest, and that both the encrypted vault and journal survive reopening.

## Important release limits
This remains a **device emulator rehearsal**, not a restore into a customer's active financial history. It cannot prove safety of the app's running SharedPreferences writes, native widgets, biometric/Google account state, receipt path cutover, storage-full handling, or an interrupted production migration. The test always uses expendable data.

Before main-branch release: all CI green, Android/iOS user-data preservation tests, a crash-safe two-resource cutover with rollback, UI consent/restore recovery handling, repeatable manual QA, and explicit release approval. Firebase integration is deferred until these non-cloud checks are resolved.
