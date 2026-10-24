# M190 — independent signed APK preflight (release NO-GO)

**Google Play remains the final phase, after real production safety evidence.**

This is an additive, read-only gate for one signed Android APK artifact.
It does not generate or modify a signing key, use Android Debug Bridge, change
Firebase/Play, enable SQLCipher, write source markers, read finance or certify
any of the 24 runtime finance routes.

## Independent verification

On a trusted workstation with Android SDK build tools installed, obtain the
APK SHA-256 from a reviewed, immutable build artifact and the expected release
signing certificate SHA-256 from a separate trusted signing record. Do not
derive the *expected* pins from the candidate APK itself; that would make the
comparison circular. The script verifies the actual APK hash, one signer, an
Android APK Signature Scheme v2/v3 signature, non-debug certificate, package
name com.waffra.app and positive versionCode. A v1-only APK is refused.

Run (replace placeholders with independently established SHA-256 values):

    python3 scripts/qa/m190_signed_apk_preflight.py \
      --apk /private/builds/review.apk \
      --expected-apk-sha256 <64-character-independent-apk-sha256> \
      --expected-cert-sha256 <64-character-independent-signer-sha256> \
      --output /private/evidence/m190-apk.json

The output is a private 0600 file created without overwrite. It contains
only public artifact identity metadata, not finance, raw device IDs, SMS,
receipt bytes, private keys, user IDs or passwords. SDK failures, a changed
APK, missing certificate, debug certificate, unexpected package, v1-only
signature or ambiguous signer fail closed.

Run deterministic *synthetic only* negative tests:

    python3 -m unittest discover -s test/qa -p 'm190_signed_apk_preflight_test.py'

The test ZIP is not a real APK; mocked SDK results only exercise fail-closed
validation logic. Passing CI is **not** evidence of an actually signed release
APK, two phones, or a production cutover.

## Next release blockers (not solved by M190)

- A trusted, actually signed APK must pass the tool on the release workstation.
- Two distinct physical Android phones must be checked using M189, then the
  installed APK identity must be independently matched to the reviewed artifact.
- All 24 live finance routes must be observed with app-signed runtime witnesses,
  not inferred from enum names, test mocks or screenshots.
- A source-backed encrypted restore with exact receipt-byte parity and crash
  recovery must succeed on the second phone; OS-backed key recovery and native
  Home/Widget lock must be attested.
- Account deletion, bilingual public privacy links, opt-in crash reporting,
  Data Safety and explicit human production GO/NO-GO remain required.

The report always sets production SQLCipher cutover and Google Play
publication to false. **State: APK artifact identity preflight only, NO-GO.**
