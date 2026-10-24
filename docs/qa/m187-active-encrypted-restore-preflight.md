# M187 — Active SQLCipher source portable-restore preflight (NO-GO)

## What is actually implemented

`WaffraVerifiedActiveRestorePreflight` is a **read-only** precursor to a future
encrypted active-source restore workflow, not a writer into active finance.
It requires an explicitly confirmed user intent, source-selected
`backupRestore` audit, current and matching SQLCipher Home/Widget source
witnesses, and the authenticated portable `.waffra` encrypted archive.

The process:

1. Rechecks the actual finance backend through
   `WaffraVerifiedFinanceAuthority.load(backupRestore)`. Rejects
   legacy-only sources, missing OS/cutover evidence, stale Home/Widget
   revision, or the absence of a verified encrypted session.
2. Fully authenticates the password-protected archive (including all
   transaction fields and receipt byte ownership) *before* opening any
   temporary destination.
3. Creates a unique OS temporary directory and a brand-new, random
   disposable SQLCipher key. **The caller cannot name its path or key**, so
   the active vault cannot accidentally be passed as the restore target.
4. Uses the existing empty-vault encrypted restorer, then independently
   attests original money fields, date, category, transaction identity,
   receipt SHA and byte-by-byte content; closes and **cold reopens** the
   disposable DB and attests a second time.
5. Rechecks the active Home/Widget source generation and SHA before
   reporting success. Any concurrent source mutation invalidates the
   result. Every exit path closes the candidate and deletes its staging
   directory and database.

The result contains only checksums, generation and financial counts.
`activationAuthorized` and `activeSourceReplaced` are **always false**.
There is **no persistent import file** to swap, no update to active
SQLCipher, no source marker changes, and no current user data deletion.
The decrypted archive and receipt bytes are never exported as a
plaintext intermediate file.

## Synthetic negative tests

`test/storage/m187_active_restore_preflight_test.dart` exercises a
pre-existing *nonempty* active SQLCipher source (so tests would detect a
destructive replacement), an authenticated incoming expense with a real
receipt, no-receipt backup, wrong password, forged encrypted envelope,
stale Widget revisions, pending cutover, missing confirmation, disabled
source and refusal of a legacy-only authority. These tests depend on
synthetic source witnesses and temporary test databases only.

## Next mandatory implementation and release blockers

**This does NOT restore into a running database or make cross-device
synchronization work.** Replacing an active source will require an
independent OS-key recovery, atomic source-pointer handoff and crash
recovery journal, widget close/reopen protocol, irreversible key handling,
rollback policy, receipt/typed module projection reconciliation, full
audit of all 24 live routes, and physical proof on **two Android phones**
including receipt bytes and no history loss.

All user-facing restore UI and destructive reset remain guarded while
these independent proofs are missing. No Firebase/Play publication or
production SQLCipher activation is attempted.

**Release state: M187_STAGING_ONLY_PRODUCTION_NO_GO.**
