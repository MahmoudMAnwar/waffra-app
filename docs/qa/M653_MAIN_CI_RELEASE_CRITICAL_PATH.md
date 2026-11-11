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
