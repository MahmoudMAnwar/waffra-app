# M217 — Connect shipped account mutations to the Home/Widget source lease

**Live code path wired; SQLCipher customer activation remains NO-GO.**

The released root `WaffraApp` previously called `SharedPreferences` directly
for `saveUser`, `logout` and `setPin`, even though Home and the separate
Android quick-capture engine route finance through
`WaffraProductionFinanceAuthorityBinding`.

M217 replaces all three real root methods with
`WaffraLiveAccountWriteAuthority`. Its guarded legacy writes run inside
`WaffraLegacyFinanceWriterCoordinator.withCurrentPreferences`, i.e. the
native **cross-engine** Home/Widget lock, where the production finance source
guard, encrypted DB/key, pending/active markers and interrupted financial
journals are checked BEFORE any account mutations. If SQLCipher has activated
or the source requires recovery, account changes refuse rather than silently
continuing to write personal information to the legacy store. PIN mutation
is also source guarded; this does not move or strengthen the existing
short-PIN verifier (M216 remains a separate candidate).

## What is real

- `main.dart` **actually invokes** the new authority on normal profile save,
  logout and enable/disable PIN. These are not isolated dead-end helpers.
- An unchanged legacy source keeps current expected login behavior and
  "welcome back" registration hints.
- Source mismatch, pending cutover, invalid profile schema and malformed PIN
  are rejected before a write. The finance ledger and category snapshots are
  neither mutated nor cleared.
- The native lock serializes account mutations against cooperating
  Home/Widget finance writers. Synthetic tests can inject a blocked source,
  and source markers are covered by regression tests.

## Remaining mandatory steps, not asserted by this PR

This change is **not** an encrypted profile repository. The app still uses
guarded legacy account preferences while legacy is the authoritative source.
Encrypted login/profile read, write, edit and sign-out require a verified,
OS-keystore-bound principal and an atomic SQLCipher account repository
before SQLCipher may become active in the signed application.

Legacy SharedPreferences writes are not all-or-nothing multi-key SQL
transactions: a process crash between a profile field and login hint may
still leave a partial legacy profile. This PR must not be described as
guaranteed crash-atomic or as having removed plaintext from old devices.

Still outstanding: all 24 live finance routes, receipt byte parity, encrypted
backup/restore and source recovery, two distinct physical Android phones,
account deletion verification, signed APK user acceptance and separate
production cutover authorization. No automatic source switch, store upload,
Firebase data transfer or Android signing change is made.
