# Waffra coding-agent rules

Before any implementation, register the change as a numbered GitHub Issue and in docs/WAFFRA_REQUIREMENTS.md; link its target PR, test coverage and current status. Keep protected edits bounded by docs/qa/approved_change_scope.json and docs/qa/behavior_contract_review.json.

docs/release/WAFFRA_APPROVED_CHANGES.txt is the SHORT CURRENT SAUDI APP release-summary file, not a running list of retired features. Its historical predecessor is archived byte-for-byte under docs/release/archive/WAFFRA_APPROVED_CHANGES_PRE_M645_20261111.txt. Never advertise removed Qwen runtime, receipt OCR or retired image-entry/quick-capture UI as available.

For EVERY production code change, after committing the app source and BEFORE pushing the PR update, run:
  python3 scripts/qa/m449_prepare_release_notes.py --issue ISSUE_NUMBER --pr PR_NUMBER --summary "Owner-reviewed factual source changes, not a release certification" --commit

The command stamps the real most-recent production-source commit SHA, commits only the approved notes, then runs the original fail-closed M449 ancestry check. Do not synthesize product claims from filenames, skip M449 or automatically push changes from untrusted pull_request_target Actions. For test/docs-only updates run:
  python3 scripts/qa/m449_prepare_release_notes.py --verify-only

Signed APK/AAB builds must use main only and retain mandatory Flutter, verified finance, native Android, and security checks. M410 has manual-only single-failed-emulator-job recovery; it must not retry failed assertions or superseded/fork commits. M267 two-phone identity requires real phone evidence; Skipped is never a pass.

Never hide a regression by deleting a test or treating source-only CI as proof of physical performance, migration, or store release readiness.
