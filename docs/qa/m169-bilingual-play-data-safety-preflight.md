# M169 — privacy policies, Play Data Safety and live-vs-planned feature inventory

Candidate source: PR #165 `0242b54d1e77f1539eef3fa12d77e06fbc9eeabf`. Draft policy updates are **not published**.

## Corrections made
- Both Arabic and English privacy policy **drafts** now acknowledge `firebase_crashlytics` as installed in `pubspec.yaml`. The SDK being in the binary is NOT evidence of active event collection; Flutter's reviewed-build flag defaults false and CI scripts suppress Android native auto collection.
- Play Data Safety draft distinguishes installed SDK from independently unverified transmission, default behavior, optional consent and retention.
- The app handles manually entered amounts and deliberately pasted SMS only; it does not use online banking credentials or bank account integrations.
- No untested assertions of production SQLCipher-only persistence, E2EE multi-phone sync, functional remote deletion or no third-party data processing.

## Required owner and Play Console sign-off
| Data class | Actual feature | Disclosure and evidence needed |
|---|---|---|
| Firebase Auth account data | Google login | SDK data collected/shared, identifiers, encryption in transit, retention and delete requests |
| Financial records and pasted message text | Manual finance/clipboard paste | Real release source, device vs encrypted cloud data paths, processing and permissions |
| Attachments and receipts | User-selected on-device files | Backup export, optional transfers and deletion |
| Crash/device diagnostics | Crashlytics SDK installed; collection gated OFF | Native/Flutter opt-in, automatically captured metadata, processors and withdrawal behavior |
| Device and usage metadata | Firebase/Play transport and other included SDKs | Actual SDK inventory and declared Play categories; don't infer none |
| Backup/recovery key | V2 .waffra and experimental source | No plaintext key upload, retention and recovery documentation |

**Hard blockers:** real publisher and support identity, actual live AR/EN HTTPS policy URLs, functioning public & app account deletion, verified production SDK behaviors and Android permissions, final Play Data Safety submission, financial features declaration, and Store listing/artwork approval.

Run `python3 scripts/qa/m169_policy_consistency.py` and `python3 -m unittest scripts/qa/test_m169_policy_consistency.py -v`. These audits may pass without satisfying Play launch requirements. No page uploaded, Play form submitted, app published or Firebase configuration deployed.
