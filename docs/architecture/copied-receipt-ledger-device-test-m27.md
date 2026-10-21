# M27 — Android/iOS runtime verification of the offline file-to-ledger chain

This milestone adds an Android emulator integration test that runs an entirely **synthetic**, password-encrypted Waffra backup through:

1. M16 encrypted archive verification.
2. M19 receipt sandbox staging.
3. M24 planned attachment remapping.
4. M25 independently verified copy to another empty temporary folder.
5. M26 encrypted SQLite import + projected SQL receipt-path parity.
6. Cold reopen of the encrypted database, read back of entry records, verified receipt path references, and exact copied bytes.

The test is part of the existing Android integration workflow and must pass on-device, in addition to the host Dart analyzer/storage tests.

**No Firebase is needed for this test.** It uses fresh temporary local database and directories, with an injectable test-only key, and deletes disposable artifacts after execution. It does not access any existing Waffra user's transactions, account, preferences, old receipts or security settings.

This is not yet a release-approval gate for production data cutover: no cross-resource activation or power-loss rollback, no freeze of app/native-widget writers, no imported live records, no iOS test runner, and no recovery UI. Those must be implemented and reviewed before modifying the active financial data source.
