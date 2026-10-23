# M170 — Crashlytics opt-in, native-default-off and confidential diagnostics

## Source-reviewed findings
- `firebase_crashlytics` **already exists** in `pubspec.yaml`. Never claim it is missing.
- `WAFFRA_CRASHLYTICS_READY` compile-time reviewed-build flag defaults false, independent of end-user consent.
- Android CI injects native `firebase_crashlytics_collection_enabled=false` into the generated application manifest BEFORE app startup.
- `WaffraCrashlyticsOptIn.synchronize()` requires persisted consent AND reviewed release config; opt-out invokes `deleteUnsentReports()`.
- Allowed Waffra event payload is a static `WaffraSafeDiagnosticCode` enum; sender passes safe tags only.
- New M170 disposable sender tests exercise denied-before-opt-in and static tag output. They **do not send any real Firebase events**.

## Prohibited in diagnostics
No bank SMS or transaction details, money amounts, phone/email/account identifiers, Firebase tokens, receipts/paths, passwords, raw exception.toString or stacks that may expose PII. SDK automatic device/crash metadata still requires vendor/dependency and Play Data Safety review.

## Validation
`python3 scripts/qa/m170_diagnostic_source_audit.py`
`flutter test test/m170_crashlytics_no_sensitive_payload_test.dart test/m106_diagnostics_privacy_gate_test.dart test/m107_release_backend_gating_test.dart`

## Release blockers retained
Verify built signed APK's merged Android Manifest, native-first-launch with **zero collection pre-consent**, opt-in, opt-out, cached reports purge, Crashlytics dashboard with synthetic data only, and real SDK data-processor disclosure. No crash injected, Firebase console monitored or collection enabled in this milestone.
