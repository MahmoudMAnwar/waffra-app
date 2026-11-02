# Waffra Smart Incremental CI

The Android workflow has two modes:

- **Main release candidate (default main pushes):** run the entire Flutter/Dart and
  Python QA suite exactly once in the mandatory verification job, **in parallel**
  with the independent same-commit workflow auditor. The signed ARM64 APK and
  Google Play internal-testing AAB build job starts **only after both gates pass**.
  The build job does not re-run static analysis, Smart CI or Flutter tests already
  covered on the exact main SHA; release signing and artifact identity remain mandatory.
- **Full (`android-full-smoke.yml`, nightly or manual):** run *all* Flutter tests,
  build an x64 APK and launch Android in an emulator, then build signed ARM64 APK.
  Full smoke is a separate workflow; regular push jobs do not show skipped emulator steps.

The previous **Smart Incremental CI** machinery remains available to historical
non-main QA branches. It is no longer a second execution of Flutter tests during
the normal main release build. The full-suite job always executes every test,
including newly created and security-critical tests. Main release candidates
never treat cached pass fingerprints as proof of a newly executed test.

The parallel same-SHA auditor still fails closed on missing, pending, or failed
workflows. It requires both the M340 finance-quality gate and M174 post-merge
regression to exist and succeed on main, avoiding a race where an early empty
GitHub API response could incorrectly allow release.

## How passing test results are reused

1. \`scripts/smart_ci.py\` discovers every \`test/**/*_test.dart\` file.
2. It hashes the test, recursive local Dart imports, relevant sources, all assets,
   native/platform configuration, pubspec and lock file, workflow/policy, and the
   actual Flutter/Dart toolchain identity. Tests that use \`main.dart\` conservatively
   include **all** project library Dart sources in their fingerprint.
3. The latest cached result is **only trusted if it came from a successful signed
   historical QA build**, because those branches save the results *after* successful
   APK upload and release signing verification. A failed run never produces a trusted cache.
4. If the file and all its known inputs have the same fingerprint, a previously
   passed, noncritical Flutter test file can be marked as \`Reused — unchanged inputs\`.
   Source, toolchain, assets, workflow or dependency changes invalidate the relevant
   previous results. Unknown imports fail closed and include all project Dart sources.
5. Financial calculations, bank-message parsing, validation, recurring payments,
   savings and encrypted backup security tests **always execute**, even when the
   cache fingerprint is unchanged.

On historical QA branches, the GitHub Actions Smart CI summary reports how many
**test files** were executed and reused. It does not count a cached result as
a newly executed test. On main, no cached file result is trusted instead of
the exhaustive same-SHA Flutter test invocation.

## What is not cached

- The outcome of an actual Android startup/emulator smoke test is not reused
  as proof of startup after native Android or Firebase changes.
- APK signing and integrity checks always run for each newly created APK.
- Flutter static analysis always runs in the mandatory main verification job before APK generation (and separately in historical QA preview builds).
- A successful fast APK run does **not** imply an on-device crash check was run.
  Full smoke checks Android startup in a separate nightly/on-demand workflow.

## Safety checks

To test cache invalidation rules, run:

\`\`\`bash
python3 -m unittest discover -s scripts -p 'test_smart_ci.py' -v
\`\`\`

To force all Flutter tests and an Android emulator startup smoke check, open GitHub Actions,
select **Waffra Android Full Startup Smoke (Nightly or Manual)** and click **Run workflow**.
The normal **Build Waffra Android APK** workflow generates signed ARM64 APK and a separately validated candidate AAB on main, after its mandatory full test suite and exact-SHA workflow audit.
Neither fast nor full runs use a previously signed APK as the final artifact.

For the first smart-enabled build with no trustworthy cached manifest, all Flutter
tests are executed, and successful results are stored for future matching runs.
A documentation-only change is a convenient follow-up to verify that reuse works.

## M381 optimization limits

This change removes redundant **sequential** verification from main; it does not
shorten Android compilation, skip Play AAB signature or install tests, change
SQLite/SQLCipher storage behavior, or authorize public Google Play release.
The APK and candidate AAB still build sequentially in the same release job.
Measure step runtimes before claiming a specific percentage reduction.
