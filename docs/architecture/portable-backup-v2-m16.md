# Storage M16 — encrypted offline finance + receipts backup (draft)

The current Waffra v1 encrypted backup contains finance JSON but does **not**
include receipt image bytes. A device replacement could therefore restore
transactions and still lose all saved receipt images.

This isolated v2 **prototype** adds an encrypted, manually supplied archive:

- Only explicitly allowed financial SharedPreferences keys are accepted,
  including SMS deduplication hashes and custom goal suggestions. PIN,
  passwords, tokens, raw bank SMS, bank credentials and any unknown top-level
  field are blocked. The user never connects a bank account.
- Original transaction JSON, monthly settings, categories, goals, recurring
  schedules, deletions, postponements and merchant rules are preserved.
- Every receipt reference must have exactly one associated binary payload;
  both missing and invented attachment references fail the export. Store
  receipt bytes by transaction ID and order, not local file paths.
- The entire finance snapshot **and** the receipt bytes are encrypted using
  the current WaffraSecureBackup AES-256-GCM password protection.
- Restore **preview only** rejects plaintext old backups, validates original
  preflight and checksum, checks every binary SHA-256, association, count and
  length, and never changes any local files or databases.
- Per-file and total size limits block very large or malformed archives.

## Safety and remaining work

1. Implement a manual export UI and a secure on-device receipt byte reader.
   Do not log the receipt paths, archive password or decrypted contents.
2. Develop a full restore transaction that safely stages files in a temporary
   private directory and rewrites legacy receipt paths only after verified
   checksum/parity. On failure, restore the original records and receipt files.
3. Add account/vault binding choice and merging/conflict UX; never silently
   overwrite financial history on a second device.
4. Perform a backup-password KDF security review, platform-specific
   file-access/permissions test, memory/load test, Android/iOS mobile tests,
   and verify all formats with real (consenting) user samples.
5. Current `WaffraSecureBackup` still supports older plaintext v1 imports for
   compatibility; **this** verified v2 preview deliberately does not.
6. A verified preview is NOT an installed restore system or production-ready
   recoverability promise. Receipt file bytes are not synced to Firestore.

No `main.dart` edit, production database cutover, cloud writes or Firebase
permission changes are part of this pull request.
