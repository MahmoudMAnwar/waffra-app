# M504 — Weekly safe retention of failed PR workflow runs

Tracked by [GitHub Issue #425](https://github.com/MahmoudMAnwar/waffra-app/issues/425). Owner requested automatic housekeeping on 2026-11-06 after PR #402 merged to `main`.

This is **not** cancellation and does not replace existing M453 superseded-run cancellation. It only applies to **finished failure records** attached to a **merged PR** and at least **seven full days old**.

The workflow runs weekly (Sunday 02:19 UTC, GitHub scheduling subject to delays). Manual **Run workflow** with default `dry_run=true` prints a preview; turning dry-run off requests deletion. The cleanup job only runs from this repository's `main` on schedule or manual dispatch. CI on pull requests executes offline policy tests only, without write permissions or cleanup.

Runs are *preserved* if they are on `main`, unrelated to an exactly identified merged same-repository PR, open/unmerged PR runs, still running, successful, cancelled, skipped, more recent than seven days, forked/unknown, release/security/backup/SQLCipher/migration/production evidence, or have even one GitHub Artifact. Before deletion the code requires a **later successful run of the same workflow on the same PR and feature branch**, checks no artifacts, and re-reads the target state. Unavailable API evidence always means **keep**, never guess. It limits deletion to 20 per execution, scans a bounded set of historical failures, and writes counts and the run IDs it deletes to its own GitHub Actions log.

Unlike changing repository-wide retention settings, this routine **never deletes successful runs** or currently available Android APK/AAB build artifacts; all `main` runs, including old failures, remain available. It does not change GitHub's platform-wide Actions retention setting, budget, repositories, commits, issues, PRs or published releases.

**Operational limits:** GitHub can delay weekly scheduled runs, GitHub API pagination/rate limits can defer deletion until later weeks, and a merged PR with no reliably linked newer success is intentionally not pruned. Logs of a deleted workflow run are not recoverable from Actions; maintainers should keep or flag any failed run needed for an unresolved investigation. Existing retention policy may delete old run data independently of M504.

Local safety tests: `node --test test/qa/m504_failed_run_retention.test.cjs`. See `.github/workflows/m504-pr-failed-run-retention.yml`.
