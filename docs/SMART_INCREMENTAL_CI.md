# Waffra Smart Incremental CI

The Android workflow has two modes:

- **Main release candidate (default main pushes):** run the entire Flutter/Dart and
  Python QA suite exactly once in the mandatory verification job, **in parallel**
  with the independent same-commit workflow auditor. The signed ARM64 APK and
  Google Play internal-testing AAB build runners start in parallel **only after both gates pass**.
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

M381 removed redundant **sequential** verification from main; it did not
shorten native compilation, skip Play AAB signature or install tests, change
SQLite/SQLCipher storage behavior, or authorize public Google Play release.

## M383: parallel Android artifacts on main

- The mandatory exhaustive Flutter/Python verification and independent
  exact-SHA finance + SQLCipher gate must **both succeed first**.
- The `build` job is a two-entry matrix: `apk` and `aab`, each on its own
  clean Android runner. Both use the same approved source SHA, Firebase
  configuration and release signing. The APK no longer waits for the Play
  bundle build before its signed QA artifact is published.
- APK: verify signature, embedded commit/branch/run ID, branch freshness,
  signed source SHA256 receipt and matching Arabic release notes before upload.
- AAB: verify Android API 36, archive integrity, certificate SHA1/SHA256,
  embedded exact source SHA and branch freshness before artifact upload.
- Each runner has a unique Gradle, Flutter compilation and historical QA
  cache-write key to prevent matrix write collisions.
- M174's separate post-merge compiler and the production real-device/SQLCipher
  safety requirements are unaffected.

**No measured speedup percentage is promised before observing the next
main run.** Parallel cold Android runners can still have significant setup and
compilation cost, and GitHub's overall duration is the slower of both jobs.
A green AAB is a candidate for internal testing, not Google Play approval.

## M410 — Targeted rerun for a transient CI failure

**No code change / same SHA:** GitHub Actions can rerun one failed job
("Re-run jobs" -> failed jobs) while keeping previously successful jobs and
workflows untouched. Do **not** commit a no-op change just to restart CI.

**Automation (active only after this workflow is merged to default branch):**
M410 watches the M274 Android UI workflow. Only when exactly one failed job is
the known Android-emulator job, logs contain a known VM service / ADB-offline
failure and no application assertion, and the PR head SHA is still current,
it requests **one rerun of that failed job only**. A second failure stays red.
Other failures require diagnosis, not automatic forgiveness.

**Code fix / new SHA:** all mandatory exact-SHA release/security gates still
need fresh evidence. Relevant development tests should run first, but full
Flutter/Python and independent financial gates remain required before main APK.
The M410 workflow does **not** replace, skip, or cache release acceptance.
The historical Smart CI reuse policy still excludes critical financial tests.
If GitHub Rulesets require other checks, those checks must keep functioning;
never path-skip required checks into a permanently pending state.
