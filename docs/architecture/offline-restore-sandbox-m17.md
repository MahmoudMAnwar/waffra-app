# M17 — verified encrypted backup restore in a disposable sandbox

This offline test exercise stitches together M16 (password-encrypted financial
snapshot including receipt bytes) and M5/M10 (strict local migration and
relational parity checks).

`WaffraOfflineRestoreDryRun.verifyIntoSandbox`:

1. Requires an explicit experiment flag and a private sandbox vault ID.
2. Decrypts and validates a v2 archive; checks every receipt's contents,
   SHA-256, source key allowlist, financial source checksum and reference count
   BEFORE writing a database row.
3. Runs `stageSnapshot` and `buildRelationalProjection` inside a single
   OUTER SQLite transaction against a disposable encrypted test DB.
4. Requires exact transaction and financial total parity; errors abort the
   transaction rather than installing incomplete financial history.
5. Exposes redacted status flags only; never logs entry titles, amounts,
   account identifiers or receipt paths.
6. Supports exact repeat imports idempotently, but refuses staging a different
   archive into the same vault.

## Deliberate safety boundaries

- The verified `WaffraBackupV2Preview.receipts` bytes are checked but NOT
  written to the phone filesystem. Receipt path remapping is still required.
- Sandbox state is NOT an active vault. No SharedPreferences values change,
  no account binding or live ledger cutover, no Firebase or network calls.
- A real replacement-phone restore requires a secure temporary file store,
  binary receipt staging, explicit account/vault selection, backup of existing
  data, atomic transfer of original and receipt associations, rollback and
  user-facing conflict resolution.
- Need actual Android/iOS device tests, password custody and KDF review,
  full screen navigation / background writer safety, legal security approval.
- Staging proves financial parity, NOT availability of cloud sync or
  irreversible overwrite safety on production devices.

Stacked on PR #19. Do not merge to main or activate a cutover until these
conditions are tested and separately approved.
