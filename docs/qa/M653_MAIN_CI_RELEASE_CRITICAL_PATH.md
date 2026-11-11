# M653 — Main Android release CI critical path (2026-11-11)
Issue: https://github.com/MahmoudMAnwar/waffra-app/issues/579
Status: Partial — registered before CI code edits; exact-head and post-merge main measurements pending.

## Timed evidence
At main SHA 37030c8, run 43059887405 completed in 18m50s:
- mandatory Flutter/Python regression job 9m50s, with complete Flutter test ~8m48s;
- external same-SHA audit job 13m53s;
- signed APK runner 4m50s AFTER both verifiers;
- signed AAB runner 3m33s in parallel with signed APK.
M340 full Flutter was also run independently on the same main SHA; M174 CI-only native APK compiled again; an unrelated Nightly/Manual startup smoke (run 43059887414) completed at 16:49:37, five seconds before external same-SHA audit ended at 16:49:42. This was an avoidable dependency, not necessary app/release validation.
Across latest 100 main-listed Actions at audit time, 85 were historical M410 workflow_run Skipped; PR #568 already changed this trigger to workflow_dispatch only.
Main M647 prune run 43083569171 failed because unittest attempted to import 'test.qa'; use unittest discover -s test/qa -p 'm647_main_history_prune_test.py'.

## Exactly required main-release gate after scope
1. Verify on actual main SHA: analyzer, all Flutter tests, every Python QA test, smart-CI test and M340 source guard plus hostile negative tests. No incremental fingerprint shortcut.
2. Exact-SHA independent M174 Main SHA Post-Merge SQLCipher Regression and M449 Release Notes Freshness must be present and succeed. When M201 route-acceptance workflow is triggered on same SHA, it must also succeed.
3. A missing, pending, failed, cancelled or skipped required check blocks. The audit continues to requery latest run per name for the checked SHA; no stale success and no PR head fallback.
4. Maintenance workflows (M453/M647), manual/scheduled Android startup smoke, old M410 no-ops and duplicate unsigned M174 compilation must not delay signed build, but must retain their own test and failure reporting.
5. Only after (1) and (2): signed APK and AAB are freshly built, identity verified and release notes generated; APK only from main. M174 unsigned native compile is manual on demand and remains available.
6. PR M340 still executes source contract, critical finance and every Flutter test. On main these are all covered by full mandatory test/guard job, avoiding duplicate full Flutter jobs. No weakened finance, encryption, migration, rollback, signing, or SQLCipher test assertions.

## Regression plan
- M653 source tests assert all above, correct M647 discover runner, M410 manual-only and no automatically skipped no-op.
- Preserve M381/M382 assertions for exhaustive/branch-safe release; reconcile only historical M340 main-push and M174 duplicate native-push assumptions to verified new roles.
- M385 changed file and bounded function scopes, M550 behavior registry, M449 latest append-only release note.
- Main post-merge measure run duration and compare with baseline 18m50; goal 14–16 min where runner availability and cache conditions permit, no guaranteed duration.


## M654 — Root cause of the newly failed M147 Android build on PR #580
- Issue https://github.com/MahmoudMAnwar/waffra-app/issues/582; exact PR HEAD fbfd011d, run 43086351577, job 130751731090.
- M147's Flutter suite and source review passed; only ARM64 CI-preview compile failed at `:firebase_core:lintVitalAnalyzeRelease`, `JavaDocParser`, `NoSuchMethodError: java.util.List.removeLast()`. Runner confirmed Temurin JDK 17.0.21. Android lint toolchain fault, not Waffra finance code or the application's widget tests.
- Google tracked this as AGP Android Lint #522845800 and fixed it in AGP 9.3.2: https://developer.android.com/build/releases/agp-9-3-0-release-notes . Gradle's compatibility table supports JDK 21 runtime from Gradle 8.5 onward.
- Bounded workaround: use Temurin 21 + actual version preflight before Android Gradle/Lint in five key CI paths: M147 exact-head ARM64 review, `android.yml` signed APK/AAB, M274 emulator UI, M174 manual unsigned ARM64 compile, and Android nightly/full smoke. Do not disable lint, alter generated Gradle versions, or claim production native/physical-device certification.
- Test `test/qa/m654_android_lint_jdk_compatibility_test.py` guards all five runtime pins, runtime assertions, no lint bypass and intact signed source/finance release checks. Scope M385, behavior M550 and release note M449 updated on same PR.
- **Status: Partial — fixes committed to Draft PR #580; exact-head repeat of M147 native compile and clean main signed APK still required.**
