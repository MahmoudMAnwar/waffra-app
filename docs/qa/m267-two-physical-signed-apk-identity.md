# M267 — independently compare the exact signed main APK on two Android phones

**Purpose:** Close the APK identity gap between a successful GitHub build and
two privately connected physical phones. **This is NOT proof of the live 24
finance routes, SQLCipher activation, migration, backup restoration or release
eligibility.** This milestone changes no Flutter finance source, data or keys.

## Before running locally

- Use one GitHub **Build Waffra Android APK** artifact from the current
  **main** commit after all required jobs are green. The artifact must contain
  `Waffra.apk` and `waffra-qa-build-receipt.txt`.
- Verify the known, independent signing **certificate SHA-256 fingerprint**
  against the release keystore / published verification record. **Do not copy
  this value from the untrusted APK** you're about to check.
- Install that same signed QA APK on **two authorized, distinct real Android
  phones** containing only disposable test finances. Provide Android SDK tools
  `adb`, `aapt` and `apksigner` in the local PATH.
- Connect both devices by USB with debugging authorized. Device serials,
  account credentials and financial contents must stay out of logs, CI and
  support tickets.

## Read-only local command

```bash
python3 scripts/qa/m267_signed_two_phone_apk_probe.py \
  --apk /private/main-build/Waffra.apk \
  --receipt /private/main-build/waffra-qa-build-receipt.txt \
  --main-sha "<exact-40-character-main-commit>" \
  --trusted-signer-sha256 "<independently-known-cert-sha256>" \
  --output /private/waffra-evidence/m267-device-apk-match.json
```

The script refuses a missing/stale receipt, wrong embedded source commit,
non-main artifact, missing v2/v3 signature, wrong package name/signing
certificate, emulator, single or unauthorized handset, split APK, unreadable
installed APK and byte-level differences between the two installed base APKs
and the reviewed downloadable APK.

The ADB `pull` operation copies **only the installed public APK binary** from
`/data/app/.../base.apk` into a temporary private directory for SHA-256
comparison; it does NOT access the application's private SQLCipher database,
transaction data, texts, receipts, photos, or keys. If the Android security
policy denies APK copying, the result is **no proof**, not a skipped pass.
The temporary copies are deleted automatically. The private evidence JSON
contains only per-run salted device tokens and non-sensitive APK metadata.

## Interpretation

A successful command proves only that the two inspected Android devices had
an identical exact signed QA APK installed at the time of the check. The
result deliberately contains:

- `live_finance_route_witnesses: []`
- `source_backed_24_routes_attested: false`
- `two_phone_sqlcipher_restore_attested: false`
- `production_sqlcipher_activated: false`
- `production_release_allowed: false`

Continue independent evidence capture for all 24 actual user journeys,
cross-engine writes, signed source-backed receipt integrity, OS-key recovery,
crash replay and two-phone authenticated encrypted restoration, following
`docs/qa/m201-24-route-migration-receipt-device-acceptance.md`. The human
release gate remains separate. Never auto-activate SQLCipher or publish to
Google Play based on this local APK identity check.

**CI scope:** M267's automated tests use synthetic ZIP APKs, mocked ADB
responses and disposable fixture receipts; they are negative/contract tests,
**not** real hardware witness artifacts.
