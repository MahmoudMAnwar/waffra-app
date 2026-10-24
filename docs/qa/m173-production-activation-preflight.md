# M173: prepare SQLCipher production cutover — no live activation

Reference integration source: [PR #165](https://github.com/MahmoudMAnwar/waffra-app/pull/165), exact starting commit `b05576d25d49d3e0fa06265fec2768cf56ef58e9`.

## Why
The user authorized immediate continuation and safe code merging, and asked to prepare production activation. **This milestone does NOT turn SQLCipher on.** It prepares testable activation gates without modifying a person's finances or weakening the two-witness protection.

## Proven from source, not yet proven in production
1. The app models **24 different live finance routes** (startup, Home, Widget, category, goals, recurring, receipts, backup, undo, transaction save). `WaffraFinanceRouteAudit` does not consider a route verified merely because it is enumerated.
2. SQLCipher source transition requires independent SQL witness + external pointer + key recovery; inconsistent signals fail closed. The existing production guard explicitly says `all_live_writers_not_yet_routed`.
3. The release-level gate separately requires a signed real-device acceptance, two physical phones restoring, account deletion, published privacy and data-safety, diagnostics, expiry clock and explicit release approval.
4. Even with an artificially all-green fixture, the production decision has `automaticallyActivateSqlCipher=false`. Synthetic CI must never mark actual deployment ready.

## Added
- M173 Flutter tests: all 24 missing routes tested one-by-one; eight combinations of SQL/marker/key witnesses; two physical devices and signed Android treated as individually mandatory; fictional green test still does not activate anything.
- Read-only Python audit: can detect accidental change enabling automatic activation or weakening route/physical-device prerequisites.
- Explicit **NO-GO** JSON report with missing production evidence, suitable for CI artifact. No bank SMS, balances, receipt paths, Firebase tokens or device IDs in artifact.

## Safe execution
`flutter test test/storage/m173_production_release_negative_matrix_test.dart test/storage/m123_production_cutover_release_gate_test.dart test/storage/m83_cutover_release_gate_matrix_test.dart`

`python3 -m unittest scripts/qa/test_m173_source_cutover_preflight.py -v`

`python3 scripts/qa/m173_source_cutover_preflight.py`

## Hard blockers to actual enablement
- 24/24 production readers/writers must be routed to ONE SQLCipher authority. Unit mocks cannot prove this.
- Real Android cold start + nonempty backup/migration/receipts, crash rollback, key loss and cross-process Widget lock must pass.
- Actual signed APK installed on a test phone and encrypted recovery across **two separate physical devices**, with real app-version SHA recorded.
- Firebase account deletion, a functional public deletion page, published AR/EN privacy URL, Data Safety, diagnostics consent, release signing and Play-delivery OAuth are verified before store shipment.
- Final human-reviewed production cutover decision and separately authorized deployment path; no activation based on GitHub tests or preference toggle alone.

**No `main` change, SQLCipher marker, migration, Firebase deployment, user data purge, Play upload or claimed physical-device test in this milestone.**
