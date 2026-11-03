# M420 — Cloud LLM bank SMS enhancement: OpenRouter, not yet live

Status: **Server adapter + mock tests only, disabled; NO deployed endpoint, NO user SMS upload.** Changes stay inside draft PR #352.

## What the current offline analyzer actually is
- `lib/main.dart`: deterministic bank SMS amount and direction parser.
- `lib/waffra_sms_intelligence.dart`: small trained multinomial Naive Bayes intent model, completely on-device; requires high confidence (0.84).
- `lib/waffra_auto_sms_policy.dart`: conservative finance posting validator.
- Qwen is not needed for banking SMS and is not part of this architecture.
- The user had asked for features independent of a downloaded on-device Qwen model.

## Cloud flow intended to match Genie's approach
`Android SMS → local financial filter + OTP exclusion → locally redacted candidate → separately consented authenticated Firebase Cloud Function (region me-central2) → server-only OpenRouter structured JSON extraction → local source validation → existing locked finance writer → saved notification after durable commit`

**OpenRouter is an API broker**, not a bank SMS parser itself. The selected underlying LLM supplies the extraction. No evidence identifies Genie's exact model. Model choice and provider policy should be benchmarked against Saudi Arabic/English test messages.

## Added in this PR
- Server-only `functions/openrouter_sms_extractor.cjs` with mock tests.
- Structured JSON schema for operation type (income, expense, transfer, card settlement, uncertain), amount, original currency, merchant, fee, account last four, date, review flag.
- Explicit cloud opt-in required in request.
- Reject OTP/verification messages and unredacted long identifiers before any remote call.
- OpenRouter provider flags `zdr: true`, `data_collection: 'deny'`, `require_parameters: true`.
- Fails closed if disabled, model/key missing, provider fails, or output is invalid. Returned suggestions are **never directly verified for posting**.

## Still required before any actual traffic
1. Choose a structured-output-supported OpenRouter model/endpoint and validate current price, retention, jurisdiction, output quality, and provider policy.
2. Add authenticated callable Cloud Function with Firebase Auth, App Check enforcement, quotas/rate-limits, per-owner signed *separate* consent, abuse protection, bounded cost and environment feature flag. Never deploy an unauthenticated LLM proxy.
3. Configure the OpenRouter API key **in Firebase Secret Manager**, never in GitHub, Flutter or APK. No key has been created or configured in this PR.
4. Build user-facing Arabic and English cloud data disclosure, toggle, withdrawal, Data Safety and retention rules. The SMS-read permission **does not imply consent to export any SMS**.
5. Keep a **local fallback** for users who decline cloud processing or are offline.
6. Validate every suggested amount and direction against original bank SMS and currency evidence; no LLM certainty score overrides deterministic accounting policy. Transfers, card settlements, account mapping and FX remain review-only until proper accounting.
7. Deploy staging only after written privacy/data-transfer evaluation for Saudi Arabia; OpenRouter ZDR does not by itself guarantee processing remains within Saudi Arabia.
8. Real-device background execution, signed AAB, Play approval for READ_SMS/RECEIVE_SMS and Play Data Safety review are independently required.
9. Operational monitoring must log only counters/latency/error codes, no raw financial SMS, recipient, IBAN or LLM prompts.

## Why no direct OpenRouter call inside the Android app?
A mobile API key can be extracted from a distributed APK. It would expose paid quota and private message contents to misuse. Therefore **all paid provider traffic must originate from an authenticated backend**.

## Test commands
`node --test functions/test/openrouter_sms_extractor.test.cjs`
`npm --prefix functions test`

Official docs:
- https://openrouter.ai/docs/api/api-reference/chat/send-chat-completion-request
- https://openrouter.ai/blog/insights/zero-data-retention/
- https://openrouter.ai/privacy

**Release flag remains disabled.** Enabling this requires the developer to connect secure credentials, select a compliant endpoint, and complete the consent, backend security and Android tests. Nothing here represents a live integration or approved cloud data transfer.
