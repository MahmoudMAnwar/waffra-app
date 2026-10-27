# M279 — Waffra app-wide security testing roadmap and release gates

This pull request adds **automatic security controls** without modifying finance
records, encryption settings, Firebase infrastructure, production keys or users.

## Verification layers and evidence
1. Source-level fail-closed scan + mutation tests: Firestore public access,
   owner checks, account-deletion tombstone, ciphertext-only allowlists,
   AEAD portable backups, OS secure PIN *candidate* staging, disallowed
   Android manifest permissions (READ/RECEIVE/SEND_SMS, READ_CALL_LOG,
   READ_CONTACTS, MANAGE_EXTERNAL_STORAGE, QUERY_ALL_PACKAGES, etc.).
2. Fresh synthetic Flutter tests: Argon2id+AES-256-GCM backups, new-export
   password minimum, non-deterministic salts and nonces, wrong password,
   tampering, malformed archive headers, AES-GCM authenticated cloud payload
   metadata, malicious field injection, wrong keys, ciphertext mutation,
   replay as another record/vault and forbidden cloud settings.
3. Re-run existing production-source boundary, PIN, encrypted profile,
   SQLCipher active-restore and cloud-cipher tests, not mock positive
   assertions alone.
4. Firebase emulator: wrong/anonymous owner access, plaintext schema
   rejection, immutable delete protocol, recovery-code envelope, mutation
   revisions and stale-device rules. An isolated NPM dependency audit rejects
   high/critical advisories. No deployed production Firebase is touched.

## Whole-app manual and physical-device expansion — not yet automated
| Surface | Security misuse cases still needing real-device acceptance |
| --- | --- |
| First launch, login, Google/Apple/phone | Auth replay/expiry/reauth, provider account mix-up, revoked tokens, offline login |
| PIN, biometrics, system lock | Brute-force/rate limiting, OS secure verifier cutover, background blur, screen-capture restrictions, recent-app thumbnails |
| Home, all five footer sections, balance | Private data during task switching/screenshots, lock and account switch, deep-link privilege |
| Manual transaction, Edit, SMS import, Widget and shared SMS | Injection via extreme malformed input, duplicates/concurrent commit, no inbox permission, crash-safe partial import, account isolation |
| Categories, goals, recurring, budgets, Smart Tools | Input abuse, deleted entities resurrection, stale writes, parser misuse, untrusted external data URLs |
| Receipts, attachment viewer, PDF/export | Oversized/corrupt file, path traversal, MIME mismatch, safe previews, cache/temp cleanup, unauthorized share intents |
| Backup/export/restore, device migration | Password guessing throttling, copied/tampered archives, delete/restore rollbacks, two real phones, encrypted local key retention |
| SQLCipher and legacy migration 24 paths | Hardware-backed key, actual file ciphertext, WAL/journal/cache, failed migration rollback, crash recovery and cross-device rekey |
| Firebase sync, recovery, account deletion | Firestore deployment identity and permissions, revoke stale devices, conflicts, recovery code loss, owner-subcollection purge |
| Notifications, Analytics, Crashlytics | No private values or bank text in logs, error reports, notifications, test evidence; opt-in behavior |
| Android/iOS platform | Final merged release manifest permissions, app backups, TLS trust, Android exported components, iOS ATS/keychain/entitlements, deep-links |
| Dependencies and distribution | Dart/native supply-chain advisories, integrity of release SHA, debug flags, production signing cert, secret-scanning |

## Critical limitations
- GitHub host tests and Firebase emulator do not establish all 24 production
  SQLCipher routes are activated or protect live user data. No SQLCipher cutover.
- The checked-in repository does not include a complete native iOS Runner.
  ATS, associated domains, universal links and keychain entitlements cannot
  yet be validated on a signed iPhone app.
- The current PIN secure-storage work is a disabled-by-default **candidate**.
  Legacy short-PIN SHA-256 is low entropy. Do not call this a production-ready
  brute-force defense or claim physical biometric bypass has been ruled out.
- Native Android permissions must be checked again on the **merged release
  AAB/APK**; inspecting checked-in Kotlin and manifests isn't enough.
- No penetration test (dynamic instrumentation, rooted/jailbroken device,
  man-in-the-middle proxy, API backend attack) or physical Android/iOS testing
  has been completed just by this PR.
- Tests use invented finance/identity details; no secrets, user accounts,
  live Firebase deployments or CI logs containing bank SMS.

## Merge/release criteria
Keep changes isolated until exact-HEAD CI is green. Then integrate them with
the UI/UX, responsiveness and performance PRs, and run full source/security/
mobile build tests on **one combined commit**, not on separate PR heads.
Actual production approval additionally requires signed-device
authentication/privacy, recovery and ciphertext checks plus a manual security
review (OWASP MASVS/MASTG is a useful organizing benchmark).
