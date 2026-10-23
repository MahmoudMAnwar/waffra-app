# M171 — signed Android AAB / Firebase Google OAuth / Play supply-chain readiness

## Candidate build review
- GitHub `.github/workflows/android.yml` already builds a signed ARM64 APK and an API36 signed **AAB internal-test candidate**.
- Keystore is loaded from GitHub Actions encrypted secrets at run time. The repo must never commit/attach the keystore or signing passwords.
- CI validates APK certificate SHA-1/SHA-256 against Firebase-registered release certificate; actual fresh Google OAuth login is NOT guaranteed by this source gate. The workflow warns that checked-in google-services.json could predate the release SHA-1.
- AAB source currently executes `unzip -t`, `jarsigner -verify`, creates SHA-256 artifact, but doesn't independently confirm AAB signer identity or embedded package/SDK on artifact. M171 adds a **manual offline verifier** for AAB signer SHA256 + Android package/API36 via bundletool.

## Before store release
1. Download actual AAB from **same candidate head SHA**; record run URL, commit SHA, checksum, versionCode/versionName and GitHub artifact ID.
2. Execute `bash scripts/qa/m171_verify_signed_aab.sh app-release.aab` with Android/bundletool utilities; provide `BUNDLETOOL_JAR` if not on PATH.
3. Verify Firebase Google OAuth upload signing cert and Google Play App Signing delivery cert separately (they may be different). Test real Google sign-in on Play-distributed internal test.
4. Validate unique versionCode, package `com.waffra.app`, API level, Arabic/English app name, target country and Play financial features declaration.
5. Complete internal/closed test (including relevant account eligibility) and explicit owner release approval. Never automatically deploy to Production track or activate SQLCipher source.

Run source audit: `python3 scripts/qa/m171_release_candidate_source_audit.py`.
Run negative gates: `python3 -m unittest scripts/qa/test_m171_release_candidate_source_audit.py`.

**No actual AAB downloaded, signed/installed, Play uploaded, or secret inspected in this milestone.**
