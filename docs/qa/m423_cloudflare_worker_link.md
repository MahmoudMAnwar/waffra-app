# M423 — Waffra → Cloudflare Worker → OpenRouter (staging)

**Status: GitHub candidate only; NOT deployed to Cloudflare, not merged into main,
not a production APK release.** This change extends existing draft PR #352
without placing provider API keys or the staging token inside Flutter.

## What was verified externally by the owner on 2026-11-03

The owner's existing staging Worker at
https://waffra-sms-staging.mahmoudmanwar159.workers.dev/analyze
responded to a *manual*, secret-protected POST with:
- `ok: true`, `unverified: true`, `review_required: true`
- one expense, `SAR 75.00`, `TEST STORE`, with verbatim source quote.

That proves an OpenRouter response from **the OLD manually authenticated Worker**
for one synthetic English input. It does not prove the signed mobile client,
token verifier, quota binding, new Worker deployment or actual accuracy across
bank formats. No real customer SMS was used or should be used in staging.

## GitHub code added

- `lib/waffra_cloudflare_sms_gateway.dart`: opt-in, redaction-before-upload,
  Firebase ID token bearer, endpoint allowlist, strict validation of returned
  source quote/amount/currency/direction, timeout and review-only result.
- `lib/waffra_sms_cloud_service.dart`: when compiled with
  `--dart-define=WAFFRA_SMS_WORKER_URL=https://waffra-sms-staging.mahmoudmanwar159.workers.dev/analyze`,
  use Cloudflare transport only after separate account-level consent and signed
  Firebase user authentication. Default builds have no Worker URL and keep the
  existing Firebase-callable path. Missing identity, refusal and provider error
  fall back to offline recognition. This does not grant direct finance writes.
- `cloudflare/waffra_sms_worker.mjs`: source-controlled candidate to **replace**
  the old Worker after approval. It validates Firebase ID JWT RS256 signatures,
  issuer, audience, expiry and user ID against Google public signing keys.
  Requires consent per request, uses a Cloudflare Rate Limiting binding before
  calling OpenRouter, and returns a single unverified suggestion, never a
  confirmed transaction. Existing staging token disabled unless explicitly
  enabled for disposable manual tests.
- `cloudflare/waffra_sms_worker.test.mjs` and
  `test/m423_cloudflare_sms_gateway_test.dart`: deterministic synthetic
  Arabic/English, SAR/JOD, mismatched amount, fake quote, wrong currency,
  declined/OTP, transfer uncertainty, duplicate response, no-token, rate-limit
  and provider-failure scenarios.

## Owner steps AFTER exact-PR tests pass (not required now)

1. Complete secure Saudi phone/password **server-side** authentication and
   migration of existing Google users, keeping their original UID and ledger
   intact. Current M422 PR #353 is a local-only draft; it is **not** signed
   Firebase phone authentication and cannot authorize this Worker.
2. On Cloudflare, set **nonsecret** text variable `FIREBASE_PROJECT_ID` to
   the exact Firebase Auth project ID. Leave existing
   `OPENROUTER_API_KEY` Secret unchanged if the owner declines rotation,
   with the acknowledged exposure risk.
3. Configure a Cloudflare Workers Rate Limiting binding named
   `SMS_RATE_LIMITER` (example Wrangler JSON below). It is approximate by
   datacenter, *not* a strict 30/day globally; set an OpenRouter key spend cap
   and require proper anti-abuse controls before production.
4. After privacy and signing review, deploy the new Worker code to a distinct
   staging Worker first. The old Worker should remain intact for rollback.
   Never enable `ENABLE_STAGING_TEST_TOKEN` in production. Do not send the
   current staging Secret to the mobile app.
5. Build a QA APK with only the **public** Worker HTTPS URL above as the
   dart-define. Signed Firebase account + explicit cloud consent are needed;
   then test signed Android on two phones, cloud refusal/revocation, offline,
   transfer/fee, Arabic/English, fraud/OTP, duplicate and app relaunch. Existing
   offline SMS parsing must continue without the model.

Example Cloudflare rate-limit configuration (namespace ID must be unique per
Cloudflare account; 5 requests per 60 seconds per authenticated user per
Cloudflare location):

~~~json
{
  "ratelimits": [{
    "name": "SMS_RATE_LIMITER",
    "namespace_id": "1001",
    "simple": {"limit": 5, "period": 60}
  }]
}
~~~

Cloudflare rate limiting is approximate and may exceed the number briefly.
Documentation:
https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/
Firebase JWT verification reference:
https://firebase.google.com/docs/auth/admin/verify-id-tokens

## Production NO-GO

- PR #353's local phone password cannot be trusted by a server or equated
  with Firebase Authentication; never put that local password or its hash in a
  Worker request.
- The existing Worker only accepts the manually created staging token, not
  Firebase ID tokens. **It must be upgraded separately** before app requests
  can succeed; a 401 is the correct failure until then.
- Cloud provider privacy, Saudi PDPL cross-border assessment and real signed
  Android consent/device tests are pending.
- `openrouter/free` plus zero-data-retention provider restriction may have
  no eligible free model at a particular time. In that case requests fail
  closed and offline recognition continues; never silently disable privacy
  restrictions or initiate paid calls.
- A model suggestion (even if it matches SAR 75.00) is always
  `verifiedForPosting: false`, `requiresReview: true`; no funds move from
  this response. The legacy ledger and backups stay untouched.
