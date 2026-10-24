# M25 — Disposable receipt-file copy rehearsal

After authenticating an M16 encrypted archive and verifying staged receipt bytes, the experimental copier makes a *second* byte-for-byte copy into a **new empty disposable directory**. It first recomputes and compares the M24 remapping plan; it does not trust arbitrary destination paths from a caller. Every source byte is independently compared to the authenticated backup before writing, and every destination file is flushed and read back for SHA-256 verification.

Safety behavior:
- Default disabled; strict preflight of source, destination and remapped finance plan.
- Exclusive file creation; does not overwrite preexisting files.
- Never uses an old absolute receipt path or raw entry ID as a filename.
- On error, best-effort cleanup of only newly created disposable files. The **entire** disposable target must be discarded after any failure, even if cleanup appears successful.
- Synthetic failure-injection test exercises interruption after the first receipt and checks originals remain unchanged.
- No changes to legacy SharedPreferences, active user files, the real vault, account state or Firebase.

## Important limits

This is a disposable file-copy test, **not** a production restore or crash-safe two-resource transaction. The caller must isolate both directories from other writers; it cannot safely be invoked on a live user receipt directory. Copy success does not imply a transaction is committed, and a prepared M24 path plan is not activated.

Before live data migration, implement one durable state machine that coordinates writer freeze, encrypted finance database, attachment file set, activation marker, rollback after process kill/disk-full, and UI confirmation. Confirm preservation on Android/iOS before considering a general release.

Firebase remains the final separate stage.
