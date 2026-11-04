# M421 — Connected Firebase → OpenRouter SMS cloud pipeline (staging candidate)

Status: **CODE WIRED, NOT DEPLOYED; feature flag defaults OFF**. PR #352 only. This is the full application→callable→OpenRouter pathway, with no API key inside Android, APK or GitHub.

### Implemented
- Waffra settings: Account → Security & privacy → optional cloud bank SMS analysis, with separate bilingual disclosure, cross-border notice and explicit agreement.
- Flutter client `lib/waffra_sms_cloud_service.dart`: authenticated Firebase Callable Function in `me-central2`, Firebase App Check (Play Integrity for release; allowlisted debug tokens for development), per-user opt-in and reliable local fallback.
- `lib/waffra_sms_cloud_redactor.dart`: local redaction of long account/card numbers, IBANs, payment references and personally named parties; refusal of OTP and personal/nonfinancial messages.
- Backend `functions/index.js`: `setWaffraSmsCloudConsent` persists per-Firebase-uid consent and `analyzeWaffraBankSms` rechecks it with Firebase Auth and enforced App Check before invoking OpenRouter. A Firestore atomic daily quota (30 per user and ≥3s between calls) limits cost. No raw SMS is persisted on the server or logged.
- `functions/openrouter_sms_extractor.cjs`: server-only secret, structured financial facts JSON, restricted provider routing (`zdr: true`, `data_collection: 'deny'`, `require_parameters: true`). Invalid responses fail closed.
- Background SMS worker can request a cloud interpretation of an opt-in financial SMS, stage validated suggestion back into the device's Android Keystore encrypted candidate queue and show the suggestion at review. **The LLM cannot directly record money**. Local bank amount/direction/currency evidence and the atomic finance journal remain authoritative; discrepancies require manual review.
- Refusal, unavailable model, guest without Firebase Auth, unavailable internet or disabled feature fall back to offline recognition. No cloud request without separate consent.

### Still needed for an actually working external service

1. The owner must access the real Firebase project (same project as Waffra's Google Sign-In) and ensure Cloud Functions Gen2, Firestore and Cloud Secret Manager are available, with billing and Firestore security rules restricted appropriately.
2. Enable Firebase App Check → Android Play Integrity with the correct signing certificate and project app registration; for CI/dev device, allowlist a specific debug token (never commit it).
3. Obtain an OpenRouter account and API key and store it as `WAFFRA_OPENROUTER_API_KEY` in Firebase Secret Manager **outside the repository**:
   `firebase functions:secrets:set WAFFRA_OPENROUTER_API_KEY`
4. Choose a model with tested strict JSON-schema output, compliant provider routing and documented data processing/retention. Set a private deployment environment value `WAFFRA_SMS_LLM_MODEL=<approved-provider/model>`, and explicit `WAFFRA_SMS_CLOUD_ENABLED=true` only after review.
5. Deploy **only** the two new functions, not the unrelated account-deletion function:
   `firebase deploy --only functions:setWaffraSmsCloudConsent,functions:analyzeWaffraBankSms`
   (after correct project selection and staged review).
6. Run signed Android tests across a real bank SMS, offline fallback, model timeout, consent revocation, account switching, and background worker restart. Complete Saudi PDPL cross-border assessment, privacy notice and Google Play Data Safety/SMS permission review.
7. Enable cost/budget alerts in Firebase and OpenRouter, configure Firestore TTL for `waffraSmsCloudRateLimits.expiresAt`, and monitor only anonymous operational counters. Reconcile PR #352 with other active PRs before main merge.

### Deployment stop

**No credentials or Firebase project administration are exposed by the GitHub connector.** We have not set a secret, selected a paid model, configured App Check in the real project, deployed a function or sent real bank data to OpenRouter. A green CI run does not prove the provider connectivity. Production and Google Play release remain blocked pending those steps.

Official technical references:
- https://firebase.google.com/docs/functions/callable
- https://firebase.google.com/docs/app-check/cloud-functions
- https://firebase.google.com/docs/functions/config-env
- https://openrouter.ai/docs/api/api-reference/chat/send-chat-completion-request
- https://openrouter.ai/blog/insights/ai-data-residency/
