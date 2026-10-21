# Waffra Smart Incremental CI

The Android workflow has two modes:

- **Fast (default pushes):** validate static analysis, test the cache decision policy,
  run all safety-critical Flutter tests and only re-run other Flutter test files if
  their content or known transitive dependencies changed. Build and sign ARM64 APK.
- **Full (nightly / manual run with \`run_smoke=true\`):** run *all* Flutter tests,
  also build x64 and launch Android in an emulator, then build signed ARM64 APK.

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
- This cache does **not** imply a financial integration or on-device crash check
  was run when the job skipped the Android emulator.

## Safety checks

To test cache invalidation rules, run:

\`\`\`bash
python3 -m unittest discover -s scripts -p 'test_smart_ci.py' -v
\`\`\`

To force all Flutter tests and an Android emulator smoke test, open GitHub Actions,
select **Build Waffra Android APK**, click **Run workflow** and enable \`run_smoke\`.

For the first smart-enabled build with no trustworthy cached manifest, all Flutter
tests are executed, and successful results are stored for future matching runs.
A documentation-only change is a convenient follow-up to verify that reuse works.


## Android incremental build cache experiment

The Android release workflow also enables `org.gradle.caching=true`, using the
**existing** `gradle/actions/setup-gradle` cache of Gradle User Home and the
local Gradle task output cache. Dependencies already downloaded are therefore
not the only reusable part: outputs of Gradle tasks that explicitly support
caching may be reused when their input fingerprints match.

We additionally restore `.dart_tool/flutter_build` from a compatible prior
successful build. The cache key includes the Flutter framework/engine revision,
dependency lockfile, native configuration and workflow. Flutter itself checks
Dart/asset dependencies and recompiles stale outputs.

These caches **never replace** the final APK build, application signing,
certificate verification or Flutter tests. No signing keystore or signed APK is
placed in the explicitly cached Flutter compilation directory.

To prevent upload/download overhead from outweighing benefits, the Flutter
compilation cache is saved only when it is nonempty and at most 500 MiB.
GitHub Actions summaries report whether the cache was restored, plus measured
ARM64 build-command duration. Benchmark successive successful runs using:
- Cold cache: build after a cache-configuration change.
- Warm cache: documentation-only follow-up with exactly the same app source.
- Source-change run: modify an actual Dart/native source and verify rebuild.

For a fair performance comparison, record whole-run time and ARM64 build-command
time separately. Cached output does not imply all tasks can be skipped;
correctness always takes priority over apparent speed.
