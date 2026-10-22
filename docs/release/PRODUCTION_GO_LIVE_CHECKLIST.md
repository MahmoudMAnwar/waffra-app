# Waffra Production Launch — Go/No-Go Gates

**Owner:** Release manager, QA and security. **Status:** NOT READY. Branch preparation is not store publication.

## Gate 1 — Finance safety (release blocking)
- [ ] All 24 live Home/categories/goals/recurring/attachments/backup/Widget finance routes read and write the exact same verified SQLCipher authority
- [ ] Source cutover two independent witnesses agree; keys are OS-backed and biometric/recovery rules verified
- [ ] Legacy finance and receipts migration with non-empty historical fixtures, crash/restart injection, replay prevention, atomic rollback
- [ ] No bank-account permission, bank connection or automatic banking credentials
- [ ] Full Arabic/English/dark/RTL/PDF app QA; fresh app and upgraded old app
- [ ] Firebase E2EE sync on two physical phones, offline conflict, reconnect, opt-in consent, lost phone/key recovery, ciphertext-only diagnostics
- [ ] Account deletion data purge tested end-to-end without resurrecting records from cloud backups

## Gate 2 — Play policy and privacy (release blocking)
- [ ] Release AAB targets **Android 16 / API 36+** and has tested OS behavior/edge-to-edge layout
- [ ] Actual package ID com.waffra.app matches Play entry and configured Firebase OAuth client
- [ ] Confirm Play target API/SDK and declaration requirements at submission date
- [ ] Public bilingual privacy-policy page published under stable HTTPS link, externally accessible without sign-in
- [ ] Real publisher legal name, support/privacy email and data deletion URL configured
- [ ] In-app account deletion and external web deletion request path function with Firebase Auth/backend data cleanup
- [ ] Data Safety form completed from SDK and data-flow audit, not policy drafts
- [ ] No raw SMS/receipts/balances in Crashlytics, logs, analytics or CI artifacts
- [ ] Sensitive platform permissions audited; no READ_SMS or READ_CALL_LOG
- [ ] Content rating, financial features declaration, country, ads/target age and app access test credentials resolved
- [ ] Closed testing requirement checked for Play developer account creation date; if applicable 12 opted-in testers for **14 continuous days** before applying for production

## Gate 3 — Signed release supply chain
- [ ] Keystore stored only as GitHub encrypted secret, never in repository/artifact
- [ ] Android App Bundle (AAB) built with **same reviewed SHA**, Android API 36 or newer
- [ ] Release signing SHA-1/SHA-256 verified against Firebase registered Android OAuth certificate
- [ ] AAB metadata target API, package ID, versionCode/versionName and signing verified before Play upload
- [ ] Google Play App Signing registration/upload key ownership established
- [ ] No duplicate versionCode, debug flags, debug keystore or staging Firebase endpoint
- [ ] Release build downloaded, signed and installed with launch/login/financial data smoke on *physical* phone
- [ ] Play internal/closed testing then gradual rollout with staged percentages and tested rollback/update path

## Gate 4 — Observability and incident response
- [ ] Crashlytics SDK configured correctly for Flutter+Android; **native automatic collection disabled by default** if opt-in policy used
- [ ] Explicit in-app opt-in/out control and persisted consent; native collection semantics tested
- [ ] Sensitive diagnostics allowlist: **no raw exception messages, SMS, financial values, access tokens, phone numbers, receipt paths, recovery codes**
- [ ] Android ANR/crash-free rate and critical financial-write exceptions reviewed daily during first rollout
- [ ] Incident owner/support response mailbox verified, incident severity and data-protection escalation process documented
- [ ] Defined rollback / halt rollout thresholds based on crashes, failed login, migration mismatch, receipt loss or data consistency

## Gate 5 — Store publishing
- [ ] AR/EN store title, short/full description matched to features in submitted binary
- [ ] Feature graphic 1024 × 500, Android icon and final verified screenshots with **synthetic** data
- [ ] AAB uploaded to **internal testing first**, Google sign-in works on Play-installed build (app-signing SHA differs from upload key)
- [ ] Closed test signups and required production access approved, only then staged rollout
- [ ] Actual public privacy and deletion URLs embedded in Play Console and app

## Explicit release decision
The current M99–M105 branch is NOT approved for Production. PRs can be reviewed and tests may pass without proving all live SQLCipher routes, a real two-phone E2EE restore, public account deletion, or physical-device Play AAB install.

**Never bypass release blockers by making the audit workflow return success.** Record evidence for each gate and approved signing SHA before any merge or upload.
