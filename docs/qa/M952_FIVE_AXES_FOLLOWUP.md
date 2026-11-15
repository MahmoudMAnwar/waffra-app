# M952 — Proactive Financial Reliability & Code Hardening (Issue #657, Draft PR #658)

Baseline: merged #654/M944 and #656/M949–M951; **115 new functional Dart cases are already on main**, and are not double-counted here.

This is the *latest* 2026-11-15 five-axis plan of 20 proposed hardening improvements. It is **not** the old numbered M944 five-axis plan.

| Axis | Verified existing baseline | New M952 code tranche | Test / evidence | Current status |
|---|---|---|---|---|
| 1. Financial integrity | Verified encrypted finance authority, fixed-halalas, duplicate suppression, goal/due/transfer invariants | Account readiness now fails closed before reading money-linked tables if domain schema lost | New disposable SQLCipher m952_account_linked_schema_readiness_test.dart plus existing M948/949–951 | Partial; exact-HEAD CI pending |
| 2. Accounts and Backup/Restore integration | Portable V3 encrypted archive, legacy V24 safe restore path and independently confirmed account links | Account read gate validates all versioned finance-domain tables, schema revision and original account FK checks | New corruption/revision tests plus existing m440_accounts_portable_v3_test.dart | Partial; real owner's old archive not tested |
| 3. Performance and responsiveness | Verified keyset source pager, 50-card Home window, 100-card SMS window | Cache immutable full sender ID lists per review revision; refresh after confirmed individual or bulk removal | Extended m940_sms_review_page_window_test.dart source contract; full queue selection preserved | Partial; no Android FPS benchmark |
| 4. UI stability | Existing approved Home/Goals/Recurring, static +, snackbar, RTL narrow-screen coverage | No visual change in this tranche; preserved all geometry and SMS original-text display | Existing M948 widget and M274 UI matrix, Android screenshots separately required | Audit only |
| 5. Architecture and proactive QA | M944 separated Home parts, M949–M951 new functional suites and M937 reporter | Reject duplicate runner starts, duplicate suite ID, unknown suite origin; three new hostile-stream tests | m937_flutter_test_report_test.py with unchanged exact-SHA pass/fail/skip and privacy | Partial; exact-HEAD CI pending |

## Invariants and decisions

- Never treat a schema marker alone as evidence that all linked tables survived a restore or an interrupted migration. The finance-domain check must be read-only and fail closed, never autocreate empty money rows.
- Preserve every already confirmed financial writer, account opening, transfer, linked goal/due, rollback and cold-open invariant; no bank balance guessing.
- SMS list cache represents every sender group ID, not the first 100 visible cards. Native SMS data, selection, and original text stay untouched until explicit existing confirmation.
- Keep UI design, Arabic/English labels, fixed FAB, Snackbar anchor, and old main-part source reconstruction unchanged.
- The 20 proposed improvements are **not** all completed: remaining work includes keyset/offset consolidation, full Home snapshot avoidance, broad high-volume goals/recurring profiling, device/restore end-to-end verification and comprehensive nonduplicate tests.
- Do not mark an axis Done without committed code, relevant executable regression and passing exact-head CI. Physical handset/private encrypted archive acceptance is separate and must not be invented.
