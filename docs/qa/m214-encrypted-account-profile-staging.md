# M214 — Encrypted account-profile candidate staging

**Status: synthetic QA only; production NO-GO.**

The user wants all Waffra persisted user fields to use a trustworthy storage
system. Bank/finance records remain source-gated SQLCipher candidates;
identity metadata currently has separate SharedPreferences keys. This M214
milestone stages the non-secret **person/contact** part into the same already
finance-bound SQLCipher **candidate file** without activating it.

## Accepted fields and guarantees

- Precisely `waffra_profile`, `waffra_registered_profile`, last login method,
  last email, last phone, and explicit signed-out flag.
- No PIN hash, Firebase/Apple/Google token, encryption key, OTP or raw
  credentials go into the staging table. They require their own
  independently verified **OS-backed credential store** and review.
- `WaffraLegacyFinanceWriterCoordinator.withCurrentPreferences` obtains the
  same cross-process Home/Widget lock, validates safe legacy source, replays
  interrupted journals and reloads current preferences. The original profile
  remains completely untouched in legacy storage.
- Stage only into a database whose `shadow_migrations.source_sha256` matches
  the current canonical legacy finance preflight checksum. This prevents
  contact data from accidentally being added to another staged owner's vault.
- Validate the complete original profile JSON against the reviewed Person
  schema, refuse unknown fields rather than discarding them. Use exact
  per-key bytes on roundtrip and refuse overwriting a different staged profile.
  A SQL error or mismatch rolls back all account-table writes.
- The resulting table `fresh_account_profile_staging` does not contain
  finance ledger fields; a *finance-only reset* must not erase account
  identity and an eventual account-deletion route must explicitly clear it.
- Flutter tests use synthetic emails/phone numbers, native lock, the real
  SQLCipher key check, cold re-open and account/finance-owner mismatch.
  They never upload contact content to logs or artifacts.

## Still blocking user-device cutover

This is not a live login/profile repository: the login page currently reads
its legacy profile preferences, and no source-selection marker changes here.
Before migrating real accounts, a signed build must atomically bind account
and finance identity, test verified signed-in vs signed-out and Google/Apple/
Phone authentication flows, complete **account deletion** for both account
PII and finance tables, secure the PIN with an appropriate credential store,
and validate encrypted recovery across **two physical Android devices**.
Contact profile backup/restore and receipt-byte parity need independent
evidence. The app's 24 finance routes still need real-device attestation.

The main Android APK remains **QA-only**, and Play publishing is last.
The legacy raw-SMS privacy guard remains enabled.
