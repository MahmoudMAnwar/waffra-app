# M417/M421 — SMS first-run permission and conditional cloud interpretation

**Status: Draft, not approved for Play or production.**

First launch: the user may approve Android READ_SMS/RECEIVE_SMS or skip and continue manually. Receivers filter financial bank messages locally, discard obvious OTP/personal/ads and retain only matching candidates in an Android-Keystore encrypted, bounded local queue. Worker can save highly confident SAR income/expenses through the existing finance writer, using original SMS hashes, with notification only after verified commit. Uncertain transfers, card settlements, fees, foreign amounts and unlinked accounts are routed to review.

**Separate optional cloud consent:** granting SMS permission **does not** grant permission to send SMS content to a provider. The user can independently enable cloud AI in Account → Security & privacy. After that explicit opt-in, bank SMS matching the financial filter can be locally redacted and sent via authenticated Firebase Cloud Functions to a selected OpenRouter provider. The current candidate is feature-flagged OFF and not deployed. Model output is a suggestion, not an authorized finance write. Users can opt out and continue offline.

Go-live blockers include: exact-head Flutter/Node/Android CI green; signed-device background intake and notification proof; Firebase Auth/App Check registration and safe isolated user consent; Server Secret Manager key/model/feature flag deployed; full review of cloud processing outside Saudi Arabia; model accuracy tests; renewal/revocation; Google Play SMS permission declaration approval; updated Play Data Safety, privacy policy, account isolation and legacy financial migration testing.

No actual cloud transfer, provider credential or production deployment has occurred.
