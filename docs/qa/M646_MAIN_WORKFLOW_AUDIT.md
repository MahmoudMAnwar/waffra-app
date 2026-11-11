# M646 — GitHub Actions audit on main, 11 November 2026

Baseline main SHA: 37030c8a6a588b89478d541ef63973bc4ed63e1b.
GitHub repository directory listing included **104 workflow YAML files**. This is an inventory count, NOT 104 active checks on every push.

## Verified run-history sample

The newest 100 entries from GitHub Actions run listing filtered to branch main contained:
- 92 named M410 Bounded Failed Android UI Job Retry.
- 80 M410 entries concluded Skipped.
- Eight non-M410 entries, including main M449, M340, M174, M201, M453, Android full smoke and signed build.

The cause is the unconditional M410 workflow_run completed event listener. GitHub creates the workflow-run record even when M410's job condition evaluates false. This is not evidence of 80 failed Android tests.

**M646 correction:** M410 is now a deliberate manually dispatched recovery, requiring the precise source M274 run ID. Source is fetched in a trusted main context; original same-repo, exact PR SHA, one first-attempt Android job and infrastructure-only signature checks are retained. Application assertions, unrelated jobs, forks, and stale SHAs cannot be retried. Old skipped run history is immutable.

## Skipped and obsolete workflow classification

- M267 two-phone signed APK identity contract was intentionally Skipped on unrelated PRs through an old fixed branch guard. It does not claim two-phone proof. Keep the Python identity probe, explicit manual evidence and negative tests; do not count Skipped as green or delete device safeguards.
- M268 ten-tool historical review is locked to an old feature branch; it is not an extra mandatory main workflow.
- Removed Qwen/Tesseract OCR workflows already disappeared: M636/M640 source regressions explicitly assert that the deleted model and OCR engine do not return. Retain those negative tests.
- Several high-cost required workflows (Full Offline, M103, M160, M282, M147, M367) repeatedly execute full Flutter unit/widget tests. Their same underlying errors can make six workflows red at once. Do NOT delete finance, encrypted backup, native Android, release or source-provenance gates merely because their Flutter steps repeat. A future shared exact-SHA attested test-artifact consumer could consolidate these jobs, but only after proving equivalent coverage and immutable results.

## Signed APK main-only restriction

The signed Android release workflow had **16 old QA/feature push branches** alongside main. Removed those auto-push triggers and installed a fail-closed main-ref guard on its signed build job. The original full Flutter/Python verification, exact-SHA independent finance audit, signing, APK/AAB and native libraries verification still execute on main. Manual dispatch on another branch may run diagnostics, but cannot generate signed artifacts.

Issues #566, #567; Draft PR #568. These are source-level conclusions pending exact-head CI. Performance on the two real phones is independent and must be tested separately.
