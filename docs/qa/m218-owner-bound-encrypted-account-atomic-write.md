# M218 — Owner-bound atomic SQLCipher account mutations

**Status: experimental encrypted profile CRUD contract only; production NO-GO.**

M214 stages profile metadata and M215 reads it from an exact
SQLCipher financial source. M218 adds real SQLite account updates, including
sign-out, with source/identity validation and a single ACID transaction. A
confirmed update changes rows in `fresh_account_profile_staging`, updates
`fresh_account_profile_stage_marker.captured_count` and verifies persisted
row parity before commit. Previous snapshots and concurrent edits must match
exactly, otherwise the transaction aborts.

## Owner and source security

The API refuses to mutate unless all of the following independently match:

- It is explicitly enabled and the source guard reports an already-active
  encrypted financial source (never guarded legacy or manual recovery).
- The **existing** SQLCipher finance cutover checkpoint is `active`; shadow
  migration vault ID and source checksum match supplied independently
  verified finance evidence.
- A pre-existing `fresh_account_profile_principal_binding` owner witness
  matches an HMAC-SHA256 of version, vault ID, source SHA and current auth
  SDK principal. The 256-bit secret must be read from OS-protected storage.
  The writer does **not** create or self-approve a principal enrollment or
  key. The owner HMAC cannot be inferred from an editable e-mail address.
- All rows satisfy M214/M215's six-key allowlist, JSON person schema and
  immutable staged-row count. The caller's expected snapshot equals the SQL
  snapshot before any writes.
- The Home/Widget native writer lock is held for source recheck and commit.

No PIN hashes, OTPs, OAuth tokens, OS keys, SMS, receipts, finance rows or
UI appearance fields enter the profile table. No fallback to legacy login or
automatic source switch exists; data and owner identifiers are never logged.

## Crucial production dependency

**The live app does not yet call this writer.** It must not be connected to
UI until a separately attested, durable owner enrollment service exists,
linking the right Firebase/Google/Apple/Phone principal and Android OS key
to the finance vault without creating an empty database. Its release evidence
cannot be synthesized from test booleans or static app source.

Outstanding also include signed app+widget finance route proof (all 24),
encrypted receipt and custom-goal migration parity, backup and restore to
a second **physical Android device**, wrong-key and mid-crash recovery,
account deletion, PIN key migration, privacy policy, explicit human approval
and final QA APK validation. Google Play remains last.

M218 test fixtures use only disposable synthetic vaults, principals and keys.
**NO GO** for production SQLCipher activation or user account changes.
