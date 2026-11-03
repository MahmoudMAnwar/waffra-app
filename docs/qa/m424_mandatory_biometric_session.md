# M424 — Mandatory biometric entry after Saudi phone/password login

**Status:** draft PR #353 implementation and synthetic QA. NOT approved for
`main`, signed APK rollout or live account cutover.

## Owner-approved behavior

1. Register/sign in using Saudi phone and password in the M422 flow. After a
   successful account profile save, show the OS biometric challenge before
   opening the Home finance view. This is a *device-presence gate*; it is not
   proof that the locally saved password authenticates to a secure server.
2. Every time Waffra loses foreground activity (inactive/hidden/paused or
   detached), immediately cover finance pages with a biometric-only gate.
   Return to the app requires a NEW biometric prompt, not a 30-second timer.
3. If a fingerprint or supported biometric is missing, denied, locked out or
   cancelled, the financial screen remains inaccessible. Show a simple
   explanation and a Retry button. Allow **Sign out**, but not bypass.
   The device OS selects fingerprint/face; Waffra does not read biometric
   templates. No device PIN, app PIN or password fallback in this gate.
4. Remove both "PIN app lock" and "Change PIN" from My Account. The old PIN
   hash and existing financial data remain untouched for safe migration.
   Other legitimate OS biometric use (e.g., authorizing destructive deletes)
   is unaffected.
5. Login, logout and old Google-account one-time recovery are unchanged.
   An old signed-in profile also receives biometric protection until the
   phone-login migration is proven; never discard wife's existing history.

## Changed paths

- `lib/main.dart`: cold-start challenge, post-login challenge, immediate
  lifecycle lock, lock-screen routing and removal of optional PIN settings.
- `lib/waffra_biometrics.dart`: biometric-only, non-sticky OS challenge.
- `lib/waffra_mandatory_biometric_gate.dart`: isolated lock screen, OS
  prompt on mount, error/retry and sign-out with no PIN bypass.
- `test/m424_mandatory_biometrics_test.dart`: lifecycle, failure, success,
  unenrolled biometric and no-settings contracts.
- M422 GitHub Actions runs the added tests and analyzer.

## Blocks before shipping

- PR #353's phone/password flow is still a local legacy SHA-256 password
  check. It is NOT server-verified authentication, and must not authorize
  access to cloud SMS OpenRouter. Complete verified Saudi phone ownership,
  secure password verifier, reset, signed identity, session revoke and
  existing Google UID migration before production deployment.
- Verify no sensitive finance preview remains visible in Android Recents,
  share intents, widget deep links, task switching and native splash.
  Review screenshot/recents protection defaults separately; an app UI gate
  alone cannot encrypt finance data at rest.
- Physical Android device QA: fingerprint already enrolled, no biometrics
  enrolled, hardware unavailable, OS authentication cancellation, repeated
  Home/back/task switch, cold restart, navigation permission dialogs,
  interrupted OS prompt, lockout and accessibility. Fingerprint-only is not
  supported by all devices; the OS may provide a strong face biometric.
- iOS requires device QA as well. If biometrics are not enrolled the app
  intentionally remains locked; provide recovery/logout workflow without
  allowing plaintext finance access.
- Prove old PIN preference retention and all old finance records, signed
  APK identity and encrypted backup continuity after migration. Until proven,
  **DO NOT distribute this PR to the old Google user or merge to main**.

## Acceptance checks

```sh
flutter test --reporter expanded test/m422_phone_only_auth_entry_test.dart test/m424_mandatory_biometrics_test.dart
flutter analyze lib/main.dart lib/waffra_biometrics.dart lib/waffra_mandatory_biometric_gate.dart
```

No cloud credentials, bank messages, biometric templates or private user data
are required for these tests.
