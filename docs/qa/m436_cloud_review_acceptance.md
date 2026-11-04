# M436 — Consent-based automatic CLOUD SMS suggestions, manual financial posting

## Correction to M433 review-only behavior

User requested that a signed APK actually **analyze new and current-activation-month bank SMS** with cloud AI after standing opt-in, but **never save income/expenses without explicit review and budget confirmation**.

- Native Android SMS receiver/encrypted queue remains unchanged in its financial authority. Native receiver never uploads SMS or posts finance. Android WorkManager and the foreground inbox may request AI suggestions after separate installation-level Cloudflare cloud consent.
- Before transport: `WaffraSmsCloudRedactor.redact` locally strips sensitive references, IBAN, long identifiers and OTP text, and fails closed. The cloud request also requires Firebase App Check signed device attestation; any failure returns no suggestion, preserving the SMS for manual review.
- `WaffraSmsCloudReviewAnalyzer.stagePending` processes at most two pending messages per foreground pass and one per background worker run. Daily QA request budget is eight attempts per installation (UTC), below the shared OpenRouter free-account total. A native encrypted atomic 24-hour claim prevents duplicate requests for a single candidate even when Android worker and foreground are racing.
- Valid provider output gets staged via `WaffraAutoSms.stageCloudAnalysis` **only**, with `requiresReview=true` and no trusted finance verification. The Home SMS review card counts staged suggestions and the sender-grouped message list shows suggested income/expense amount and currency. The user's existing manual review/editor screen makes the final record and budget selection. The `reviewOnly` branch must return before `commitConfirmedSms`.
- Main push **QA APK** now includes the public Cloudflare staging URL in its Flutter dart-define. Android AAB/Play candidate remains without the staging route. No OpenRouter API key or other secret is ever built into the mobile binary. Cloudflare's real-time quotas and the actual signed Android App Check+OpenRouter E2E remain unproven until device acceptance.
- No migration or mutation of pre-existing financial data or encrypted backups.

## Required pre-production acceptance

1. Exact-head M436 CI and full Android build on `main` after merge, no skipped regression or hidden failures.
2. Install signed QA APK on disposable owner profile. Verify SHA256 against Firebase App Check Play Integrity registration and successful POST with a genuine app-attested token.
3. Opt out of cloud: zero outbound requests and still receive/review local SMS. Opt in: redact bank SMS, auto-stage a real AI hint, keep ledger and budget unchanged before the user's save.
4. First day of activation month, old/current month, duplicate SMS, restart and private notifications. One-time permission should not re-prompt each incoming SMS.
5. Foreign currencies, refunds, transfers, card settlements, unknown merchants and model conflicts. Incorrect/unverified hints are not accounting facts. Provider down, 401 App Check, 429 limits and malformed responses must retain messages for manual review.
6. Run two-Android-device acceptance and encrypted finance/goal/budget/attachment backup parity before updating family devices containing existing records.
7. Review Google Play SMS access policy, Saudi/user consent privacy and cross-border processing; staging API should not be represented as Production-approved.

**Important:** Workflow success proves source and simulated tests only. It does not prove staging attestation, that the source bank message yielded an accurate suggestion, or that old device finance data survives an update.
