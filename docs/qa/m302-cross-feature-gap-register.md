# M302 — Waffra cross-feature QA gap register (30 Oct 2026)

This is a **risk/coverage register**, not a certificate that 805 repository files or every
runtime path is defect-free. Do not interpret a successful host test as approval to store
real customer finance data on an unverified cutover.

## Current main baseline
- Repository: `MahmoudMAnwar/waffra-app`.
- Starting `main` SHA: `4615982e3b0c2391ff0b652c6def21f6b90b0f27`.
- Keep Google Sign-In functional; never rebuild from an older release or merge without
  exact-head checks, all sibling PR integration and an APK generated from `main`.
- The user-approved global currency setting changes only display denomination, never
  the underlying numbers. Real conversion is an explicit, separately verified FX operation.

## Domain-oriented review

| Domain | Existing source / coverage | Gap / mandatory next gate |
|---|---|---|
| Auth / Google Sign-In | `waffra_google_auth.dart`, `main.dart` | Test account selection, first launch and recovery on real Android/iOS. Google phone flag picker is **PR #292**, not yet on main |
| Profile, PIN and biometric lock | `main.dart`, `waffra_biometrics.dart`, account write authority | Real biometric registration, account isolation, logout and lock-after-background device tests |
| Location/country and display currency | `waffra_country_first_run_page.dart`, `waffra_display_currency.dart` | Respect manual choice over inferred location. **PR #292** pending integration; verify reinstall and country changes |
| Manual finance & validation | `waffra_validators.dart`, `waffra_amount_formatter.dart`, `main.dart` | M302 prevents Arabic near-duplicate categories and preserves 3/4-place tool inputs. Finance ledger remains cent-precision (2 places) |
| SMS/AI parsing & deduplication | `waffra_sms_intelligence.dart`, `waffra_sms_multicurrency_review.dart`, `main.dart` | All 36 display currencies need foreign amounts, balance exclusion, duplicates, income/outgoing verification on final integrated SHA. **PR #293** pending |
| Camera/gallery OCR, multiple actions | `waffra_receipt_ocr.dart`, `waffra_bank_screenshot_parser.dart`, `main.dart` | **PR #291** passed host CI but not integrated. All-currency bank-image selection and genuine bounding-box location require further work |
| Categories/search, deleted items | `waffra_category_catalog.dart`, `waffra_search.dart`, `waffra_validators.dart`, live category edit | M302 applies normalized duplicate checks to create/edit/restore. **Critical fixed:** preserve transaction SMS notes, source type, merchant key, receipt pointer and recurring start date when renaming; compare cold-read snapshots |
| Goals and recurring | `waffra_recurring_policy.dart`, `waffra_goal_catalog.dart`, `waffra_reminders.dart` | Due dates, notification permission at activation only, double-save, overdue date and recycle recovery on actual device |
| Widget / background finance | `waffra_widget_capture.part.dart`, verified source authority | Same-SHA app/widget race, crash/restart and lock/coordinator tests; never let widget read stale or wrong-account balances |
| SQLCipher production cutover | `lib/storage/**` and many isolated suites | **SQLCipher production cutover** still lacks confirmed live 24-route activation / parity and physical evidence. Never enable solely on host test success |
| Backup/export/restore | `waffra_secure_backup.dart`, `waffra_backup_files.dart`, verified encrypted restore | Physical two-device restore, wrong password, receipt bytes and note parity; preserve original if import interrupted |
| Cloud / Firebase owner isolation | `lib/storage/waffra_cloud_*.dart`, Firestore tests | Offline reconciliation, CAS conflict, wrong-owner and staged cloud recovery evidence on signed Android/iOS |
| Currency, gold and oil tools | `currency_converter.dart`, `waffra_gold_calculator.dart`, `waffra_oil_market_section.dart` | M302 input precision: currency converter 3; gold grams 4; oil units 3. Test real FX/spot quote outage and Arabic digit input |
| Analytics, reports, PDF | `waffra_financial_insights.dart`, `waffra_pdf_reader.dart`, report screens in `main.dart` | Compare export and displayed finance values on same record snapshot; zero rows, RTL and multi-page layout |
| UX, pull refresh and accessibility | `waffra_pull_refresh_scroll_settle.dart`, footer, haptics | 200% text scaling, safe areas, RTL/LTR, keyboard overlays, stalled refresh, 60/120 Hz frame tracing |
| Privacy and permissions | screenshot preference, SMS privacy, diagnostics and country opt-in | No unauthorized background SMS access; Android/iOS permission states, revoked permission, rooted-device behavior |
| Release supply chain and APK | Android workflows and exact-SHA release audit | **All-PR combined SHA** analysis/tests and signed APK from new `main` only, verify commit and signature |

## Current PR dependencies

- [#291](https://github.com/MahmoudMAnwar/waffra-app/pull/291):
  multiple image transactions/ordinal selection, not merged.
- [#292](https://github.com/MahmoudMAnwar/waffra-app/pull/292):
  location-display-currency separation and Google flag/phone prefix.
- [#293](https://github.com/MahmoudMAnwar/waffra-app/pull/293):
  all-currency bank-SMS parser and FX guard; must pass latest-HEAD CI.
- M302: narrow shared validation and precision changes independently audited here.

## Safe release decision

**NOT PRODUCTION CERTIFIED**. **Physical Android/iOS** acceptance and **Multi-currency
transaction persistence** with verified conversion consent are not complete.
The app's display-only preference does not implement native multi-currency ledger
accounting. Never silently reinterpret JOD/EGP/USD amounts as SAR. Do not alter real
finance data or enable cutover until source/receipt/backup/restore parity evidence,
device certification and merge integration pass.

No fabricated device-run evidence, no premature APK or merging draft PRs solely
because a standalone subset of tests passed.
