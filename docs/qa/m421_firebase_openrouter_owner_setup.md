# M421 — Owner setup guide for Firebase → OpenRouter SMS analysis

**Current state (2026-11-03):** PR #352 contains the Flutter client, local SMS redactor, Firebase Auth/App Check callable code, private OpenRouter adapter, and a default-off server flag. **No cloud service is deployed, no API key has been configured, and no real SMS has been uploaded.** The first environment must be a separate *staging Firebase project* and use synthetic SMS only.

## 1. Owner: create an OpenRouter key

Open https://openrouter.ai/settings/keys in your account. Generate an API key named **Waffra-SMS-Staging**, optionally with a low credit limit. Configure account privacy/data retention so the provider is restricted to suitable Zero Data Retention endpoints. The API client additionally sets `provider.zdr=true` and `provider.data_collection='deny'`. This does **not** by itself establish Saudi data residency.

**Never** place the key in Flutter, GitHub, PR comments, screenshots, pasted chat, `.env`, or an Android APK.

## 2. Owner: staging Firebase project

Go to https://console.firebase.google.com/ and create a separate project (or have an authorized administrator do so), e.g. a Waffra staging project with a distinct Google project ID. Copy only the **Project ID** and the public Android app package/app ID, not service-account credentials.

Configure:
- Billing: **Blaze** for Cloud Functions 2nd gen, Secret Manager and outbound provider traffic.
- Authentication: enable the sign-in provider used by the staging APK. Do not share test accounts with unrelated production finance data.
- Cloud Firestore: create the database for consent and daily-quota documents. Do not weaken existing production rules.
- Android app registration: match the staging application ID and signing SHA-256. Check Play Console app-integrity values if distributed through Google Play.
- App Check: register the Android app, use **Play Integrity** on signed release builds. For local debug builds only, register a private debug token in Firebase Console → App Check → Manage debug tokens. **Never commit a debug token.**
- Functions region: `me-central2` (Dammam); the configured Firebase Functions project must match the Flutter/Firebase Auth project.
- Set a Firebase/Google Cloud budget alert and monitor billing. Confirm staging App Check before enabling live provider traffic.

## 3. Developer/admin: secure server configuration from a computer

Use Node 22+, Firebase CLI, and the M421 code checked out from **PR #352**. This project has `firebase.json`, but no committed `.firebaserc`, so explicitly select a Firebase project to avoid accidental production deployment.

```bash
npm install -g firebase-tools
firebase login
firebase projects:list
git checkout feature/m417-auto-sms-financial-import
npm --prefix functions install # no package-lock.json is committed yet; generate it locally
node --test functions/test/openrouter_sms_extractor.test.cjs
node --check functions/index.js

# Replace STAGING_PROJECT_ID with the Firebase project ID seen in the console.
firebase functions:secrets:set WAFFRA_OPENROUTER_API_KEY \
  --project STAGING_PROJECT_ID
# The CLI prompts securely for the key. Do not echo it or put it in shell history.
```

Keep a **private untracked** `functions/.env.STAGING_PROJECT_ID` file with:

```dotenv
WAFFRA_SMS_CLOUD_ENABLED=false
WAFFRA_SMS_LLM_MODEL=openai/gpt-4.1-mini
```

`false` is mandatory at first deployment. The model is a provisional JSON-schema-capable candidate; benchmark quality, provider privacy, output format, and price before allowing financial traffic. Commit neither the `.env` nor secrets.

Then, **only after PR tests and security review pass**, deploy the two new Firebase callables to staging:

```bash
firebase deploy --project STAGING_PROJECT_ID \
  --only functions:setWaffraSmsCloudConsent,functions:analyzeWaffraBankSms
firebase functions:list --project STAGING_PROJECT_ID
```

This intentionally does **not** deploy the unrelated `deleteWaffraAccount` function or change `firestore.rules`.

## 4. Test without bank data

- Confirm both callables exist but `WAFFRA_SMS_CLOUD_ENABLED=false` rejects requests. Verify unauthenticated and invalid App Check tokens are denied.
- Configure a **staging APK** pointing to staging Firebase Auth and Android App Check. Do not use real user's bank SMS or the production Firebase project's auth/finance data.
- Test separately toggling *Cloud SMS AI* on/off, failed sign-in, app-check debug token registration, request quota and revocation.
- After documented privacy approval and correct provider-model routing, enable `WAFFRA_SMS_CLOUD_ENABLED=true` **only in staging** via its private `.env.STAGING_PROJECT_ID`; redeploy only the two functions. Use synthetic Arabic and English SMS, including debit, credit, transfer, fee, foreign currency, OTP, duplicate and failed/pending cases.
- The server returns `verifiedForPosting=false`. The existing local finance engine rechecks original amount/currency/direction and duplicate hash, and only then posts eligible items. No invented income/expense and no double deduction. Test Android background/locked screen and saved notification *after* durable commit.
- On model timeout/offline or user opting out, verify local-only fallback and **zero further provider calls**.

## 5. Remaining release gates

- Complete independent Saudi PDPL, cross-border, privacy policy, data retention and Google Play data-safety assessment. A Dammam Firebase region does **not** force the OpenRouter model/provider to run within Saudi Arabia.
- Obtain Google Play's approval for **SMS-based money management** (`READ_SMS`/`RECEIVE_SMS`) from a signed AAB and real demo.
- Signed Android device tests, CI green on exact SHA, user isolation, encrypted migration and backup recovery.
- Under no circumstances expose the service by turning a flag on in production before these gates pass.

## What the owner can share safely in the chat

The nonsecret **Firebase Project ID**, whether staging is configured, and redacted screenshots of the Firebase Overview/App Check page. **Do not send** OpenRouter API keys, service-account JSON files, tokens, private bank SMS, passwords or payment details.

Official instructions: 
- https://firebase.google.com/docs/functions/config-env
- https://firebase.google.com/docs/functions/manage-functions
- https://firebase.google.com/docs/app-check/android/play-integrity-provider
- https://firebase.google.com/docs/functions/locations
- https://openrouter.ai/blog/insights/zero-data-retention/
