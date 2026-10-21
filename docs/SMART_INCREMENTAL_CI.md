# Waffra Smart Incremental CI

The Android workflow has two modes:

- **Fast (default pushes):** validate static analysis, test the cache decision policy,
  run all safety-critical Flutter tests and only re-run other Flutter test files if
  their content or known transitive dependencies changed. Build and sign ARM64 APK.
- **Full (`android-full-smoke.yml`, nightly or manual):** run *all* Flutter tests,
  build an x64 APK and launch Android in an emulator, then build signed ARM64 APK.
  Full smoke is a separate workflow; regular push jobs do not show skipped emulator steps.

## How passing test results are reused

1. \`scripts/smart_ci.py\` discovers every \`test/**/*_test.dart\` file.
2. It hashes the test, recursive local Dart imports, relevant sources, all assets,
   native/platform configuration, pubspec and lock file, workflow/policy, and the
   actual Flutter/Dart toolchain identity. Tests that use \`main.dart\` conservatively
   include **all** project library Dart sources in their fingerprint.
3. The latest cached result is **only trusted if it came from a successful signed
   release**, because GitHub Actions saves the results *after* successful APK upload
   and release signing verification. A failed run never produces a trusted cache.
4. If the file and all its known inputs have the same fingerprint, a previously
   passed, noncritical Flutter test file can be marked as \`Reused — unchanged inputs\`.
   Source, toolchain, assets, workflow or dependency changes invalidate the relevant
   previous results. Unknown imports fail closed and include all project Dart sources.
5. Financial calculations, bank-message parsing, validation, recurring payments,
   savings and encrypted backup security tests **always execute**, even when the
   cache fingerprint is unchanged.

The GitHub Actions summary clearly reports how many **test files** were executed
and reused. It does not count a cached result as a newly executed test.

## What is not cached

- The outcome of an actual Android startup/emulator smoke test is not reused
  as proof of startup after native Android or Firebase changes.
- APK signing and integrity checks always run for each newly created APK.
- Flutter static analysis always runs before APK generation.
- A successful fast APK run does **not** imply an on-device crash check was run.
  Full smoke checks Android startup in a separate nightly/on-demand workflow.

## Safety checks

To test cache invalidation rules, run:

\`\`\`bash
python3 -m unittest discover -s scripts -p 'test_smart_ci.py' -v
\`\`\`

To force all Flutter tests and an Android emulator startup smoke check, open GitHub Actions,
select **Waffra Android Full Startup Smoke (Nightly or Manual)** and click **Run workflow**.
The normal **Build Waffra Android APK** workflow only generates the fast ARM64 release.
Neither fast nor full runs use a previously signed APK as the final artifact.

For the first smart-enabled build with no trustworthy cached manifest, all Flutter
tests are executed, and successful results are stored for future matching runs.
A documentation-only change is a convenient follow-up to verify that reuse works.
