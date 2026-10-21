# M19 — restore verified receipt bytes inside a disposable directory

This milestone fills the binary file-staging gap in M16/M17 without
ever altering a real user's receipt folders or preferences.

A caller must supply a newly created **empty, real directory** (no symlink)
and a `WaffraBackupV2Preview` returned by the authenticated backup verifier.
The disabled-by-default `WaffraReceiptSandboxStager`:

- Revalidates the finance checksum and all expected receipt counts.
- Rejects missing/duplicate receipt associations and excessive file sizes.
- Uses SHA-256 of `[entryId, position]` to generate filename-safe relative
  names. Untrusted old receipt paths and transaction IDs are NEVER filenames.
- Writes and flushes every receipt, reads bytes back to check integrity,
  then returns ordered relative path mappings per transaction.
- Aborts on failures and makes a best-effort cleanup of newly created files.
  The caller MUST discard the entire test sandbox if any failure occurs.
- Never updates legacy JSON receiptPath, `main.dart`, app financial history,
  Google login state, Firestore or production release settings.

### Still blocking complete on-device restoration

This writes only to a disposable sandbox chosen by tests. A real installer
must copy verified files to an app-private directory, durably journal the
planned new locations, import/confirm the target financial vault, and commit
receipt-path remapping + financial records atomically with an explicit rollback
strategy. It must handle interrupted installs, account/vault conflicts, power
loss, storage-full errors, existing live receipts and both Android/iOS.

A disposable-directory smoke test is NOT evidence that a complete app
replacement or cross-device recovery flow is safe.

Do not deploy the experimental feature or merge stacked draft branches to
`main` until full release gates and owner approval have been met.
