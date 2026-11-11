# M647 — Bounded historical main Actions cleanup (Issue #576, PR #568)

Reviewed 2026-11-11. Current GitHub API branch=main showed 1,727 Skipped, 177 Failed, 253 Cancelled (counts change). The older M410 workflow_run listener caused hundreds of empty Skipped run records. M646 stops the generator; M647 prunes historical records.

## Deliberate separation
M504's trusted seven-day cleanup only prunes redundant failed PR runs and preserves main, signed releases and security. It remains unchanged. M647 is an entirely separate **main-only** maintenance job using its own isolated Actions write permission and never fetching or executing PR code.

## Precise deletion policy
- Only GitHub Actions run records with completed conclusion failure, skipped or cancelled; branch main; approved main event; same repository; at least 48 hours since both creation and last update; not the exact current main SHA.
- Excludes successes, active/queued, PR/fork jobs, current cleanup run, recent runs, missing/untrusted metadata and every run with any GitHub Actions artifact. APK/AAB artifacts remain untouched.
- Snapshot and dedupe IDs before deletions, explicitly verify live run/head SHA/conclusion and artifact total_count before each action, revalidate live main every 25 candidates, rate-limit deletes to 250 per invocation. Strict GitHub API errors fail the job, rather than claiming to have deleted records.
- Merge into main triggers one batch through path-scoped push; a scheduled sweep runs at 00:41/06:41/12:41/18:41 UTC until legacy backlog is cleared. This avoids a huge API deletion burst. Manual workflow_dispatch defaults to dry-run and additionally requires exact DELETE_OLD_MAIN_ACTIONS_HISTORY typed confirmation before destructive execution.
- Each job writes source counts, processed counts by conclusion and example IDs into GitHub Actions job summary. Old workflow logs and history are **irreversibly deleted** when that run's deletion is actually accepted by GitHub; original repository source commits are not changed.
- Added fail-closed unit tests for recent/current-success/active/foreign/artifact/PR protection, wrong main HEAD, manual consent, pagination snapshot and bounded deletion. The existing M449, M385, M550, Flutter, Android, SQLCipher and signed main build gates remain mandatory.

## Execution status
This change is on Draft PR #568 and **cannot delete history from the PR**. GitHub connector has no Actions run DELETE/dispatch action. First deletion only after this exact reviewed change lands in main and its trusted push/schedule/manual maintenance job actually runs. No claim any record has been deleted yet.

## M647 verified GitHub API date-filter correction (2026-11-11)
- Live read-only REST check disproved the first `created=..2026-11-09` query: it returned zero old Skipped main records even though `created=<=2026-11-09` returned **1,414** matching records (query-time inventory). The original syntax would have silently produced an empty deletion snapshot.
- The trusted M647 Python cleaner now builds an explicit API-supported inclusive cutoff via `urlencode({'created':'<='+until})` to reach actual historic data. `test/qa/m647_main_history_prune_test.py` FakeAPI now rejects unsupported `created` expressions and positively requires three supported same-cutoff queries with one eligible old skipped run; existing dry-run/no-success/no-artifact/active/latest-SHA safeguards remain.
- Fix commits `068fd83c` (query) and `f2a28f4c` (negative/positive regression), after requirements and Issue #576 were extended **before the source patch**. This is API preflight evidence only, NOT proof that a DELETE was executed. PR #568 exact-head CI, safe merge into `main`, initial trusted push sweep and scheduled 250-batch reviews remain pending.
