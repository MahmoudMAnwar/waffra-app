# M215 — Fail-closed encrypted account profile candidate reader

**Production NO-GO. Read-only candidate validation; not live account storage.**

M214 created owner-associated account profile staging in an existing SQLCipher
candidate. M215 adds an independently callable, *disabled by default* reader
that checks the encrypted finance witness and immutable M214 completion marker
before returning any contact metadata. It cannot select the app's source,
update account details, authenticate a user, issue an OTP, or log PII.

## Tested contract

- The caller supplies a verified finance vault ID and exact 64-character
  SHA-256 source fingerprint. These values must eventually come from
  **independently authenticated source evidence**, never from a screen,
  SharedPreferences flag or a fabricated test value in production.
- A single SQLCipher transaction checks all three existing tables,
  exactly one staged-finance witness, its vault ID and checksum, exactly one
  completion marker, count parity, six approved source keys at most,
  and complete reviewed JSON of the two person objects.
- There is **no legacy fallback**: a missing SQL stage blocks even if
  SharedPreferences happens to contain a user profile. Account data is
  returned only as an immutable in-memory snapshot and is never logged.
- Unknown credential-like keys, corrupted contact objects, wrong finance
  witnesses, incomplete/missing markers and disabled mode fail closed.
- An empty profile is permitted only when explicitly staged and witnessed.
- PIN hashes, encryption keys, OAuth/Apple/Google/Firebase tokens, OTPs,
  screenshots and display preferences are not account candidate fields.

## Still BLOCKED for production

This reader does **not** authenticate identity. Two unrelated accounts can
have an identical empty financial checksum; the real Firebase/Google/Apple/
Phone account principal must be cryptographically bound to the database and
OS-backed key before user profiles are read or written in the app. The live
`main.dart` login/profile flows still use SharedPreferences; do not switch
them using this candidate API.

Pending: encrypted authenticated profile mutations and logout lifecycle,
PIN migration into suitable OS-backed credential protection, account deletion
and encrypted backup/restore parity, all 24 finance routes, external receipt
bytes, crash recovery, and two independent physical Android devices.
Real-account writes, source activation, cloud sync and Play remain forbidden.

Tests use only synthetic identities and synthetic device keys, never customer
data. The main signed APK remains QA-only until the independent cutover gate.
