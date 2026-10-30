# M327 — exact-head integration staging audit

**STATUS: DRAFT; DO NOT MERGE TO MAIN OR ISSUE PRODUCTION APK.**
Original main baseline: `0d18a0c423dcd42795a78f73d16c888f89c18717`.
Integration staging PR: #312, branch `integration/m327-main-readiness-20261030`.

## Source branches included in this staging tree
| PR | Reviewed head | Reconciliation |
| --- | --- | --- |
| #299 | `bf655b0a` | Android startup smoke now executes Bash-safe pipeline; workflow preserved |
| #295 | `40c43606` | 12-route financial hardening staged as entire verified source tree |
| #291 | `adf36be2` | OCR multiple-transaction scanner merged into main.dart by six exact hunks; retain stronger currency scanner |
| #292 | `b1ee1c4d` | First-run location, user-selected display currency, Google phone country picker; exact overlapping hunks |
| #301 | `30528e92` | Region-based Arabic greetings and splash; country preference independent of currency; manual onboarding reconciliation |
| #298 | `c85004f3` | Local AI download / first use / biometric removal, finance tools and SMS+OCR entry points; manual OCR multi-entry reconciliation |
| #288 | `9d42cb79` | Required-field/category validation and Arabic/Persian date digits; preserve locale-aware category name normalization |
| #293 | `7d4057b8` | JOD/CliQ bank SMS and FX review, SQLCipher Android runner; preserve already-identical safer currency scanner and M274 Bash |
| #294 | `01b216d2` | Two commits unique vs #295 are docs and tagged-route test; both **identical blob SHAs** already in staged #295 tree; source ancestry recorded here |

PR #300 (autonomous paid CI-repair bot) intentionally excluded.

## Critical resolved overlaps (code composition, NOT certified)
- Eight source PRs changed `lib/main.dart`; staged via exact context hunk validation and deliberate manual reconciliation, never whole-file last-writer-wins.
- OCR multi-entry candidate numbering and currency review remain active even when local AI review is enabled. Every financial save must still pass manual confirmation.
- `WaffraCountryFirstRunPage` keeps manually selected currency priority while separately selecting Arabic region and default currency recommendation.
- `waffra_sms_multicurrency_review.dart` retains the same full content present in #293, including supported named currencies and fail-closed unknown/foreign checks.
- `WaffraValidators.requiredCategory` and Arabic/Persian day digits are added while retaining normalized Unicode category uniqueness.
- M274 real emulator script is single Bash file with bounded DDS retry and real privacy-eye assertions.
- M202 SQLCipher Android runner remains fail-closed; prior VM-service/device-offline failures do **not** count as a pass.
- M290 CI checks explicit JOD/CliQ and all-supported-currency cases without overwriting phone-country or location flows.

## Mandatory release gates (all pending on combined HEAD)
1. Successful `flutter analyze`, static consistency of Dart source, full app/widget tests.
2. Full OCR, local model first-use/deletion, SMS/FX, Arabic/English/region, finance and consent tests **on this combined commit**.
3. SQLCipher real emulator tests, backup/restore and confirmed financial writes; production cutover remains disabled until independent physical-device evidence and human approval.
4. Android M274 emulator tap and rendering; Google authentication works; no stuck pull-to-refresh spinner.
5. All relevant pull-request CI checks pass on the exact HEAD; no skipped required checks, no silent retries of actual test/assertion failures.
6. Merge to `main` only once the composite tree has an explicit passing acceptance result. Build/sign Android APK from the *actual main SHA*; release-note text includes that SHA and precise fixes. No simulated APK acceptance.

No modification to original customer data, no auto-posting AI output and no production SQLCipher activation is authorized by staging.
