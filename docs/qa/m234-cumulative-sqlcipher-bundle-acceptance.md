# M234 — Complete cumulative SQLCipher QA candidate

**Scoped to exact main** `8a460fa3d537ee7e8343b01e49d794140e66652a`.

Combines Android #705 guarded legacy pull-to-refresh fix, exhaustive
24-route structural SQLCipher source gate, bank-original SMS side-vault
recovery inventory and strong encrypted portability, disposable note
cold reopen, and a combined financial rows + receipt bytes + bank-originals
encrypted QA archive with cold-reopen byte attestation.

M147 checks each commit's filenames, the *entire* source diff, the immutable
source verification barrier, original-note archive encryption, temporary
data destruction, all Flutter tests and Android ARM64 QA compilation on
the exact PR head. Other workflows independently exercise SQLCipher
emulator, receipt, finance and backup regression.

User requested **no user APK until SQLCipher phases complete**. This
candidate is draft and must not be merged into main, whose push pipeline
automatically builds an APK.

## Not yet release approved

- Backup+restore classes remain experimental and are not wired into
  the running Home/Widget production source selector.
- OS key persistence and loss/recovery, user/profile ownership, crash-atomic
  replacement and full 24 live routes must be independently attested.
- Two **real** signed Android phones must demonstrate receipt bytes,
  bank originals and finance equality after cold relaunch and backup restore.
- Account/profile fields, device-bound biometrics and security/privacy
  release requirements need separate attestation.

Green CI results alone are not evidence of a user-safe production cutover.

## Android CI dependency-rate-limit repair

The M234 Android emulator job was **inconclusive**, not a SQLCipher logic
failure, when Maven Central returned HTTP 429 downloading the Kotlin Gradle
plugins before launching any integration test. The QA workflow now caches
Gradle artifacts and retries ONLY the `assembleDebug` dependency-download
HTTP 429 signature up to four attempts with bounded delay. A real application
failure, SQLCipher failure, missing evidence, or repeated network failure
still **fails** the job. No test assertion is ignored.
