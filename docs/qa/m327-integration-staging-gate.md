# M327 — Integration staging, review before main

This is a staging branch, **not** a release and not a completed nine-PR integration.
Base main SHA: `0d18a0c423dcd42795a78f73d16c888f89c18717`.
First staged fix: green PR #299, `.github/workflows/android-full-smoke.yml`, running the Android emulator smoke under Bash rather than /bin/sh with invalid `pipefail`. PR #299 head `bf655b0aa83d19577546bee335e52ec3007c04a9` had four successful checks.

## Candidate PRs (source heads observed at initial staging)
- #299: `bf655b0a` — Android Bash smoke fix (STAGED)
- #295: `40c43606` — 12-route data hardening, main.dart edits
- #288: `9d42cb79` — required-field validations, main.dart edits
- #294: `01b216d2` — precision + data integrity, overlaps #295
- #292: `b1ee1c4d` — location/currency/phone; overlaps main.dart, first-run country
- #291: `adf36be2` — OCR; overlaps main.dart and SMS currency review
- #293: `6ba8240b` — bank SMS; overlaps main.dart, #292 workflows; Android emulator CI pending
- #298: `c85004f3` — on-device model, AI gates and Tools; overlaps main.dart; full CI pending
- #301: `b2555a70` — regional greetings/launch; overlaps main.dart and first-run country; Android emulator test may fail due to Dart Development Service startup (not yet resolved)

## Collision audit
- **Eight PRs change `lib/main.dart`: #295, #288, #294, #292, #291, #293, #298, #301.**
- #295/#294 overlap `lib/waffra_display_currency.dart`, validators, recurring policy, market calculators, and finance tests.
- #292/#301 overlap `lib/waffra_country_first_run_page.dart`.
- #291/#293/#295 overlap `lib/waffra_sms_multicurrency_review.dart`.
- #292/#293 overlap `.github/workflows/m290-country-reminders-multicurrency.yml`.
- Do not replace whole `main.dart` from any branch, choose arbitrary last-writer-wins precedence, or consider individual PR green checks proof that the **combined** tree is safe.

## Completion criteria
1. Identify shared versus independent commits and reconcile changed functions/fields, including all `main.dart` entry paths.
2. Verify all required PR checks on the exact current SHA; inspect skipped checks and emulator infrastructure failures.
3. Run full analyzer, core/finance/SQLCipher tests, SMS/OCR/AI integrations, Arabic/English/locale UI, Android emulator smoke on this exact staged tree.
4. Only then review/squash/merge to main and build/sign APK from actual main SHA. Release note must include exact main commit and included fixes.
5. Maintain original Google authentication and SQLCipher production safety gates. No unverified production DB switch or financial history mutation.
6. PR #300 (paid autonomous-repair bot) intentionally excluded.

This file is a live gate/checklist; any unmerged dependencies remain **blocked**, not implicitly complete.
