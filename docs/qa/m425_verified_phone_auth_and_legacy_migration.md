# M425 — Verified Saudi phone/password and in-place legacy identity migration

**Status: implementation candidate, feature disabled by default. Do not merge to main,
publish an APK, migrate real customers, or remove legacy Google recovery.**

## Architecture implemented on draft PR #353

- **Firebase phone OTP** verifies actual control of the Saudi +9665 number.
  Input remains only local 05XXXXXXXX, no email alias or country code picker.
  `lib/waffra_phone_secure_auth.dart` includes phone OTP enrollment, password
  sign-in through a Firebase custom token, and OTP-gated password reset.
- **Server-owned password:** `functions/phone_auth_core.cjs` derives each
  8–128 byte password using asynchronous scrypt with N=2^16, r=8, p=2,
  random 32-byte salt and a private server pepper. Client local SHA-256
  verifier is only a legacy fallback **when secure mode is explicitly OFF**.
  It is never consulted after the secure rollout flag is enabled.
- **One account identity:** Firebase UID remains exactly the same when a
  Google/Apple user links a phone credential to their signed-in account.
  Phone binding keys use a peppered HMAC to avoid a browsable number registry.
  A Firestore transaction prevents another UID from claiming an existing phone.
  Existing ledger owner, backup keys, budgets, goals and SMS transaction hashes
  are neither read, overwritten nor deleted by these authentication functions.
- **Login protection:** Firebase callable `waffraSignInPhonePassword`
  requires enforced App Check, a persisted account binding, matching disabled
  user/phone owner checks, constant-time scrypt verification and an atomic
  per-phone attempt limit (5 per 15 minutes). No account enumeration response.
  Server issues a Firebase custom token for the **existing** UID only.
- **Reset:** another recent verified Firebase OTP session is required before
  changing a password; existing UID is preserved and refresh tokens revoked.
- **Legacy migration:** old users first sign in with their **original**
  provider. Account → Verify and migrate account links phone ownership and
  sets the verified owner binding only if the linked UID matches the original.
  It updates the local profile *without changing the finance journal*.
  If the migration fails, nothing deletes the old customer finance history.
- **Biometrics:** M424 remains mandatory after phone/password entry and every
  app return, without an optional PIN switch.

## Disabled switches / no deploy

Both must be intentionally enabled only after staging tests and owner approval:

- Server: `WAFFRA_PHONE_AUTH_ENABLED=true` in the correct Firebase staging
  Functions environment; currently **OFF**.
- Flutter: `--dart-define=WAFFRA_SECURE_PHONE_AUTH_ENABLED=true`; currently
  **OFF**. A cache/profile alone cannot bypass a missing Firebase owner UID.

Firebase Secret Manager needs `WAFFRA_PHONE_PASSWORD_PEPPER` (random 32+
byte secret; never send to chat or commit). Cloud Functions and Firebase Auth
Phone OTP/App Check require Firebase project provisioning, supported phone
verification, billing and the owner's signing certificate. They cannot be
deployed or configured solely through a code review on GitHub.

Suggested *staging-only* functions once owner approves provisioning and after
passing CI:

~~~bash
firebase functions:secrets:set WAFFRA_PHONE_PASSWORD_PEPPER --project STAGING_PROJECT_ID
firebase deploy --project STAGING_PROJECT_ID --only functions:waffraEnrollPhonePassword,functions:waffraSignInPhonePassword,functions:waffraResetPhonePassword
~~~

Do not deploy `deleteWaffraAccount`, other Firebase functions or unrelated
production security rules. Never turn on the secure client flag until **all**
callables and App Check are proven on a signed Android staging APK.

## Tests added

- `functions/test/phone_auth_core.test.cjs` tests Saudi number formats,
  scrypt cost and constant-time verification, OTP and App Check requirements,
  duplicate owner collision, wrong/unknown users, account lockout, reset
  authorization, refresh token revocation, simulated old finance data
  preservation and fail-closed backend outages.
- `test/m425_phone_verified_identity_test.dart` checks real code paths for
  server tokens, OTP-before-profile-save, no fallback to SHA-256 when secure
  mode is on, cached owner guard, old UID migration and default-off staging.
- M422/M424 Flutter tests continue in the same GitHub Actions workflow. This
  proves **synthetic/source** coverage only until actual CI succeeds.

## Physical-device and genuine migration acceptance — mandatory

1. Use a staging Firebase project and synthetic test user. Sign into an
   existing Google account on Android device A and create five identifiable
   **fake** manual entries, goals, budgets, attachments, SMS duplicate hashes.
   Export encrypted backup and record exact counts/IDs and stable Firebase UID.
2. Upgrade **in place** to the staged phone-auth APK. Do **not** uninstall,
   clear app storage, rotate encryption keys or modify historical dates.
   Reauthenticate the original Google UID and link a verified Saudi test phone
   after OTP. Check UID identical. Verify entries and balance/goal wallet
   match and no duplicate/double deduction.
3. Sign out and sign in with phone/password, complete mandatory biometric
   unlock, background/resume and lockout checks; confirm the same UID and
   identical ledger counts.
4. Exercise incorrect password (five attempts), missing App Check, duplicate
   phone from another UID, wrong SMS OTP, reset OTP, forced offline, account
   switching, duplicate migration and interrupted enrollment. Every failure
   preserves original data and does not open Home without signed identity.
5. Device B may have no on-device finance records: **identity sign-in does
   not automatically sync a local financial ledger**. Validate an explicitly
   authorized encrypted backup/restore under the same UID, with exact hash
   and balance match, before claiming cross-device continuity.
6. Real production migrations need owner-assisted tests and rollback;
   do not run automatic upgrades of old Google data on live accounts.

## Release blockers

- Firebase project ownership and real SMS OTP/App Check provisioning, billing
  and Secret Manager **not done**. Firebase Phone Auth OTP is not a free
  guaranteed service. Do not promise zero charges or deploy the staging
  service into production.
- The Firebase custom-token flow and provider linking need signed Android/iOS
  testing and Firebase Emulator integration. The backend's synthetic tests
  cannot prove an actual signed token is issued or accepted.
- Full finance/SQLCipher migration, owner isolation and encrypted restore
  require real-device evidence. PR #352 Cloudflare SMS Worker must be
  reconciled with this identity PR on the same validated UID/session.
- No code in this candidate should force an already signed-in Google user to
  lose access before a successful verified migration. Preserve fallback
  recovery until documented signed device migration proof.

References:
- https://firebase.google.com/docs/auth/flutter/phone-auth
- https://firebase.google.com/docs/auth/flutter/custom-auth
- https://firebase.google.com/docs/app-check/cloud-functions
- https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html
