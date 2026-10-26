# M256 — read-only two-device installed APK hash preflight (NO-GO)

This is **preparatory tooling**, not an actual two-physical-phone attestation.
Green CI runs only mocked/synthetic ADB commands and CANNOT prove that a
user's Android devices, installed APK or encryption keys were witnessed.

## Fixed security boundaries

- Baseline: M255 draft PR #255, before any production cutover.
- A local release engineer/human independently pins the **exact reviewed
  source commit SHA**, independently produced test APK SHA-256 and trusted
  signing-certificate SHA-256. Entering a git SHA on the command line does
  **not** bind the APK to that source; preserve independent build provenance.
- M256 calls M190 local `apksigner` + `aapt` verification **before any ADB
  device command**, checks M189 device presence/properties, and obtains the
  sha256 of each installed `/data/app/.../base.apk` using read-only ADB.
- M256 refuses device changes during capture, APK splits, unexpectedly shaped
  installation paths, ambiguous checksums, missing files, digest mismatch,
  emulator properties and incomplete signed-APK reports. Split installs must
  be handled by a **separately reviewed full-set protocol**, not bypassed.
- Device-generated `sha256sum` output is only a *local ADB observation*,
  not independently secured device identity. A compromised ADB, shell,
  device or emulator can spoof the result.
- The script does not issue `adb install`, `adb pull`, `run-as`,
  `logcat`, financial reads, backups, data migrations or app reset.
  It never includes raw serials or installed filesystem paths in the report.
- Owner-private Linux/WSL output is created with `0600` and exclusive
  no-follow file creation. Outputs should stay outside version control;
  do not upload or paste device reports, receipts, SMS or signing secrets.

## Offline steps for the *final* human hardware phase only

Preconditions: a **source-pinned non-production signed test APK**, two
authorized Android 11+ phones with that exact standalone APK installed
by an approved independent testing process, USB debugging with permission,
a trusted laptop with Python 3 + `adb`, `apksigner`, `aapt`, and a
separate independently verified source/build/signing provenance record.

On a private Linux/WSL terminal, after placing the independently obtained
APK in a restricted local directory:

```bash
python3 scripts/qa/m256_installed_signed_apk_identity_probe.py \
  --apk /private/review.apk \
  --expected-apk-sha256 <INDEPENDENT_APK_SHA256> \
  --expected-cert-sha256 <INDEPENDENT_SIGNER_SHA256> \
  --reviewed-commit-sha <EXACT_REVIEWED_SOURCE_SHA> \
  --output /private/m256.json
```

If `sha256sum` is unavailable on either device, or the app has split APKs,
the tool **blocks** rather than asserting that hashes match. Never relax
the package/path/signing/source requirements just to force a pass.

Expected observation-only status even when checks match:
`LOCAL_ADB_HASH_OBSERVATION_ONLY_RELEASE_NO_GO`. Testers must **not**
interpret a local green script or the report's boolean as independent
proof of two genuine phones or permission to release.

## Human evidence still missing after M256

1. Independent confirmation that the reviewed source commit produced the
   pinned signed APK and same exact binary is installed on each real phone.
2. Two witnessed physical Android 11+ devices (not hosted emulators).
3. OS-backed key recovery, cold reopen, kill/restart safety, Home/Widget
   parallel writers and independently restored backup on second phone.
4. All 24 live finance routes, exact receipt-byte hashes, migration parity,
   wrong-password/corrupt-archive refusal and no source downgrade.
5. Build #705 Pull-to-Refresh reproduced/fixed on **physical testing
   installation**, privacy and account deletion, explicit human approval.

All of those remain **NO-GO** until independently witnessed. There is no
APK, main merge, SQLCipher source activation or store publication in M256.
