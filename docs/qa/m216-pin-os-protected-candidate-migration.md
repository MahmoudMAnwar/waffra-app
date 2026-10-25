# M216 — Android OS-backed candidate for existing PIN verifier

**Candidate-only; production NO-GO. The current app unlock remains unchanged.**

The app currently stores a SHA-256 verifier for a 4–8 digit PIN in
`SharedPreferences`. A short PIN has low entropy even when hashed, and a
database migration must not copy that verifier into ordinary SQLCipher
person/profile fields.

M216 provides a separate, disabled-by-default, **non-destructive** stage:
read a pre-existing 64-hex SHA-256 verifier; refuse malformed or unrelated
secure values; copy into Android's protected plugin key store; read it back;
re-read original after writing to reject a concurrent PIN change; and return
booleans only. This is NOT a production Android PIN implementation. No PIN
plaintext or digest is logged, exported or returned.

## Security boundaries

- `androidCandidate()` uses `FlutterSecureStorage` with encrypted Android
  preferences backed by the platform keystore where supported. It is not a
  proof of hardware-backed security on a particular handset.
- If the source is absent but the destination is populated, refuse as an
  orphan rather than claiming successful migration or silently recreating it.
- If protected storage fails, a digest differs, or source changes while
  copying, refuse. Never remove the legacy PIN verifier in this milestone.
- No OS key, PIN digest or user credential is copied to account SQL tables
  or Firebase, and no live unlock screen selects this candidate.
- Synthetic injected I/O tests exercise disabled mode, success, repeat,
  malformed verifier, missing/orphan data, mismatch, OS failure, bad roundtrip
  and concurrent source mutation.

## Required production work

Implement an owner-bound, crash-safe, physically attested PIN credential
migration and live PIN verification with bounded retry/backoff and biometric
semantics. Ensure sign-out, forgotten PIN, backup, account deletion, lost key,
wrong device and restoration cannot weaken finance encryption.

Test an actual Android keystore-backed installation (two distinct handsets)
before changing `main.dart` PIN reads/writes; then securely retire the legacy
verifier after exact parity and independent release authorization. A short,
unsalted legacy PIN SHA remains attackable if an attacker already obtained the
old preferences, and cannot be retroactively strengthened by this copy.

**SQLCipher production activation remains OFF, finance route witnesses and
two physical Android devices remain unverified, and no new APK is authorized.**
