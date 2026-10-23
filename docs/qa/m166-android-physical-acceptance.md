# M166 — Waffra Android final QA acceptance matrix (prepared, not executed)

**Scope:** signed APK built from the *same exact SHA* as the release-candidate PR. Branch review does not certify a phone test.

## Preflight before installing
- [ ] Capture commit SHA, GitHub Actions run URL and Android artifact SHA-256.
- [ ] Run `bash scripts/qa/m166_verify_android_apk.sh /path/to/QA.apk` on a machine with Android SDK tools; require signed APK, non-debug certificate and `com.waffra.app` package to preserve Firebase Google Sign-In config.
- [ ] Confirm signing SHA-1/SHA-256 fingerprints match the OAuth/Firebase configuration for this build **without** uploading any private keystore, tokens or account information.
- [ ] Confirm `automaticallyActivateSqlCipher => false` remains unchanged; do not install with a test that switches production source.

## Device A — fresh installation (app may be empty)
- [ ] Install QA APK on a *physical* Android phone; record Android version/model and time. Emulator or CI cannot satisfy this.
- [ ] Cold start, splash, PIN/biometric enable/disable, lock/unlock, system/light/dark theme.
- [ ] Sign in using the existing **Google** flow; verify same `com.waffra.app` registered client and no silent login regression.
- [ ] Create one manual **expense** and one **income** assigned to selectable child categories only; close/relaunch and confirm durable values.
- [ ] Paste five sample *synthetic* bank SMS (2 income, 3 expenses); confirm preview totals, approve explicitly, verify real saved count, duplicate handling and persistence after force-stop.
- [ ] Modify/delete/undo a transaction; verify category, goals, recurring due date and finance calendar do not corrupt balances.
- [ ] Attach a non-sensitive sample receipt image, close/reopen, verify file bytes/rendering and attachment count.
- [ ] Validate Android home **Widget** reads balance, handles copy/paste confirmation and cold-reopens without stale or duplicate finance writes.
- [ ] Export private `.waffra` V2 Argon2id AES-GCM archive through Android document picker; never copy archive to clipboard or expose financial plaintext.
- [ ] Attempt wrong-password and malformed archive restore: must fail *without* changing transactions or Google profile.
- [ ] Restore a verified archive and confirm expenses/income, hashes, categories, recurring settings and receipt bytes survive restart.

## Device B — cross-device test (separate clean test phone)
- [ ] Restore the same encrypted test archive and validate identical balances, transaction IDs, attachments and language state as applicable.
- [ ] Validate V1 PBKDF2 legacy encrypted archive can still **decrypt/import**; new archive exports remain V2 only.
- [ ] Do not assert cloud sync/two-device compatibility from local archive alone; record any separate Firebase sync checks and privacy permissions explicitly.

## Approval evidence
Reviewer records: tested SHA, run/artifact URLs, APK SHA-256, OS models, step-by-step pass/fail evidence, crashes (without PII), and restore byte checksums. Required hard fail on bad login, missing transaction, wrong archive digest, exposed data, or any automatic SQLCipher switch. **Physical-device QA is currently unverified.**

No data migration/erase, main merge, Firebase deployment or Play publication authorized by this document.
