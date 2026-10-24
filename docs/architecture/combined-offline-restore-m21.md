# M21 — Combined offline encrypted ledger + receipt restore rehearsal

## Outcome
`WaffraOfflineCombinedRestoreVerifier.verify` is an opt-in, default-disabled dress rehearsal that runs both sides of the M16 password-encrypted portable backup in a disposable environment.

1. Requires a separately provisioned encrypted SQLite **sandbox** and a **real empty** receipt directory (no symlink).
2. Validates vault identifier and destination before writing anything.
3. Authenticates and previews the portable backup, including receipt bytes and financial checksum.
4. Stages receipts in a disposable directory (M19) and independently audits each saved byte, exact filename, count, and file type (M20).
5. Revalidates the archive and performs the encrypted-finance relational parity dry-run using an isolated database transaction (M17).
6. Returns a minimal status report; never exposes transaction content, receipt source path, or encryption secrets in diagnostics.

## Automated coverage
- Successful combined restore of both income and expense history and attachment bytes.
- Default-off behavior.
- Wrong password refuses staging and the encrypted shadow database.
- Nonempty receipt target refuses overwrite.
- Path-like vault identifiers and non-directories are rejected.

The existing storage-preflight CI runs every storage test and static analyzer. Android encrypted vault CI is an additional gate.

## What it deliberately does NOT do
This is **not** an atomic transaction across the filesystem and database, and should never be exposed as a live replacement-phone restore. A failed rehearsal must discard BOTH disposable targets; it cannot claim they were rolled back together. No live app writes, account switching, SharedPreferences migration, Firebase calls, or release activation.

Before a production restore, add a durable cutover journal and crash-safe rollback; ensure shared app writers and widgets are frozen; verify full data & attachment parity; handle conflicts and low-disk interruptions; run real Android/iOS tests with consent and recovery UX. Keep production users' original data untouched until every check passes.

Firebase remains the **last** stage and is completely excluded from this milestone.
