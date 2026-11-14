# M937 — Phase Four: regression results and repeat-failure triage

Issue #642. Same Draft PR #640. Status: implementation committed; exact-HEAD CI pending.

The existing complete Flutter test suite still runs once with expanded logs.
An additional Dart JSON FILE reporter records events locally in the runner.
A Python script parses its completed, non-hidden tests into passed, failed,
skipped and total counts for the *same exact commit SHA*. Skipped never count
as passed. A normalized first error line is hashed to group repeated symptoms,
which are NOT confirmed unique defects; no raw error text or stack traces
are uploaded. The raw machine JSONL is not published.

The existing full-regression job now exports a sanitized JSON summary, human
readable GitHub Job Summary and a CI artifact even on failed test runs.
Missing/malformed events or inconsistent final verdicts always fail closed.
Host summary is not real Android, backup, performance or production proof.

Exact work: the parser and nine hostile Python tests, a bounded modification
to finance-full-regression.yml, and QA scope/requirements documentation.
No app runtime, finance persistence, Android permission, signing or release
code is changed. No new full Flutter test job is created.

Local reproduction:
1. python3 -m unittest discover -s test/qa -p 'm937_flutter_test_report_test.py' -v
2. mkdir -p build/qa
3. flutter test test/ --reporter expanded --file-reporter json:build/qa/m937-flutter-events.jsonl
4. python3 scripts/qa/m937_flutter_test_report.py --source-sha <exact-40-character-Git-SHA> --input build/qa/m937-flutter-events.jsonl --output build/qa/m937-summary.json --markdown build/qa/m937-summary.md
