# M53 — Real legacy receipt byte-integrity preflight

A complete Waffra migration must preserve **actual image bytes**, not just the `receiptPath` text in an encrypted finance snapshot.

This opt-in, read-only auditor runs under the same OS finance writer lock as HomeScreen and the Android widget. It examines every receipt reference inside the existing transaction records, supports the existing single-file and JSON-array formats, verifies the file is a real local regular file under an explicitly trusted app-private root (never a symbolic link or an untrusted path), hashes its bytes with SHA-256, and rechecks source finance unchanged before finishing.

The audit refuses missing, empty, oversized, unsafe, unreadable or changing receipts instead of pretending migration succeeded. A report contains hashes, byte counts and transaction ownership. The original files and SharedPreferences are never mutated, and no Firebase access is involved.

Tests cover zero receipts, one image, multiple images, byte parity, missing files, untrusted paths, empty images, corrupt finance, blocked cutover state and default-disabled mode.

## Critical limitation

This is a **preflight**, not a copy or verified restore. Existing file bytes are not automatically moved into SQLCipher. Activation requires a complete authenticated backup/copy and readback check for every image, plus one authoritative finance source, secure key handling, cold-start rollback and Android APK validation. The M25–M27 disposable receipt copier and M38 SQLCipher BLOB store are related building blocks, not yet a production migration.

Firebase setup is ready independently and remains the final integration step.
