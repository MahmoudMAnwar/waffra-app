# M167 — isolated fresh-install finance & backup acceptance

## Why this milestone matters
The owner confirmed the app currently holds **no real financial transactions**. Therefore don't invent a legacy user-data migration: test a disposable empty state and first transaction save, while still protecting Google profile/locale and retaining compatibility with older encrypted backups.

## Source paths reviewed
- `WaffraHomeFinancePersistence.saveLegacy` writes guarded financial snapshots under the app/Widget lock, preventing stale ledger/widget revisions.
- `WaffraVerifiedLegacyBackupRestore.restore` uses complete-key preflight and an atomic ledger/journal save; it must not overwrite profile/login data.
- `WaffraSecureBackup.encryptUserBackup` emits V2 Argon2id AES-GCM and `decrypt` supports V1 PBKDF2 compatibility.
- `test/m163_atomic_backup_restore_durability_test.dart` proves source-authorized durable save must precede publishing UI state (static source witness, not real-device execution).

## M167 automated scenarios
1. Explicit empty snapshot restore succeeds and leaves synthetic Google profile and language unchanged.
2. Save one test income and one test expense, reopen guarded storage and verify identical ledger values.
3. Reject a malformed backup with negative saved goal and retain the previously stored ledger, profile and journal integrity.
4. Encrypt/decrypt V2, decrypt V1 legacy encrypted archive, reject wrong password without claiming any persisted restore.

Run `flutter test test/storage/m167_fresh_install_finance_backup_test.dart test/m163_atomic_backup_restore_durability_test.dart test/storage/verified_legacy_backup_restore_test.dart`.

## Unverified/not authorized
Real physical device cold reopen and two-device restore; Android-keystore encryption at rest, signed APK Google auth, actual receipt file bytes after restore, SQLCipher production routing and Firebase synchronization are NOT verified by these disposable Flutter tests. Do not merge main or activate/migrate any finance source on this basis.
