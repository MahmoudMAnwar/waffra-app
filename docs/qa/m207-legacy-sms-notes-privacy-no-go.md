# M207 — Legacy bank-SMS notes fail-closed guard (NO-GO)

**Purpose:** Prevent the unencrypted SharedPreferences finance journal from newly
persisting original bank SMS text in `MoneyEntry.notes`. The current
production Home/Widget source is still guarded legacy storage; SQLCipher
production activation is NOT approved.

## Behavior

- `commitConfirmedLegacySms` rejects **all nonempty SMS notes** before
  touching the ledger, hash list, widget revision or recovery journal. The
  Home and Android Widget call this shared confirmed-SMS writer.
- `saveLegacy` checks the **current locked ledger** before writing. New or
  modified notes for SMS-sourced entries are rejected, including attempts to
  relabel an existing SMS entry as manual, **even if the notes are unchanged**.
  This prevents a two-save bypass (first relabel SMS to manual, then append raw
  bank text as a manual note). Already stored notes are preserved
  byte-for-byte on unrelated updates; no destructive cleanup or migration.
- Legacy and proposed ledgers with duplicate, missing or blank transaction IDs
  are rejected before SMS source comparison. Otherwise a duplicate manual row
  could shadow an existing SMS row and bypass the source/notes guard.
- Normalized transaction titles, amounts, dates and deduplication hashes may
  still be saved without original SMS notes. Manual user-written notes remain
  allowed for non-SMS entries.
- Tests use only synthetic data and a disposable writer directory. They assert
  that rejected writes do not modify the ledger, hashes or widget revision.

## Release blockers

**NO-GO.** This is a protective legacy guard, not field encryption and not
proof of a secure active finance source. It intentionally conflicts with the
unmerged M206 PR #207 request to persist complete original SMS notes; that
feature must NOT ship on plaintext SharedPreferences. Complete original SMS
notes may only be persisted after independently verified, production-gated
SQLCipher Home+Widget source initialization, OS-backed key, atomic migration,
24-route evidence, crash recovery and physical-device QA.

This patch does not change source markers, activate SQLCipher, touch existing
user data, modify Firebase or publish to Google Play. Google Play remains the
last phase after explicit user approval.

**Limitation:** This guard covers the two central legacy persistence methods,
not arbitrary future direct SharedPreferences writers or an old installed APK.
It does not certify 24/24 routes or protect existing plaintext already stored.
