# Waffra — Pre-production data-safety review and disclosure matrix

**WORKING DOCUMENT ONLY**. Do not submit the Google Play Data Safety form from guesses.
Must be rechecked against the production AAB, all included SDKs, log pipelines, Firestore collections and actual retention/deletion behavior.

| Data type | Present or plausible source | Known use | Review before store submission |
|---|---|---|---|
| Account identifier, email, name/photo | Firebase Google sign-in and optional profile | Authentication, account display | Validate fields, transmission, encryption, collection/sharing, optionality |
| Phone / local profile | User profile and login screens | User experience / local identity | Check local vs Firebase OTP actual paths, permissions and retention |
| User-entered transactions: amount/title/date/category | Manual save; pasted notifications | Financial ledger, reports and budgets | Prove SharedPreferences/SQLCipher production authority; decide finance data categories and whether optional E2EE upload ships |
| Bank notification plaintext | User-initiated copy/paste | On-device parsing/categorization | Prove no raw text is logged, sent in telemetry, or uploaded; test clipboard and lifecycle |
| Receipts/photos | User attaches receipts | Transaction attachments and reports | Verify local file vault, optional backup/cloud behavior and permission scope |
| Savings goals, recurring and spending analysis | App-entered finance data | Budgets, reminders and analysis | Verify remote sync, backup, processing and retention |
| Crash and diagnostic telemetry | `firebase_crashlytics` **is declared** in `pubspec.yaml`; collection guarded OFF by default pending reviewed release flag and consent | Stability and QA if activated | Verify native default OFF in final AAB, SDK automatic device/crash metadata, consent withdrawal, no financial labels, and Play disclosures; source dependency presence does not prove that collection occurs or never occurs |
| Notifications, biometrics and settings | OS APIs | Reminders and app security | Check permissions and whether any values leave device |
| Encrypted backups / recovery key | Experimental SQLCipher/E2EE components | Restore user finances | Never upload plaintext user recovery secrets; verify storage and deletion |
| App installs and performance | Google Play and SDK operational data | Distribution and stability | Review Google Play and Firebase SDK data disclosures separately |

**Minimum mandatory checks before approval**
- [ ] All currently used data types and each external processor identified from the **release dependency graph**, not planned features
- [ ] Collection/sharing flags, required/optional status, purpose and consent accurately entered for each Play Data Safety category
- [ ] Data encryption in transit verified for every actual network use
- [ ] No third-party advertising SDK unless disclosed and approved; no inferred claim of no telemetry
- [ ] User account deletion button and public webpage available, verified on real test account
- [ ] Deletion and retention match backend Firebase Auth/Firestore/storage and locally persisted data
- [ ] AR and EN policy URL public, resolves over HTTPS, no login required; owner/support email valid
- [ ] Delete receipts and user financial information per tested deletion protocol; no unintentional stale-backup resurrection
- [ ] Screenshots use synthetic finance amounts and test accounts only
- [ ] Special app access / SMS policy reviewed: copy-paste or Messages app shortcut only, no READ_SMS or bank integrations
- [ ] Finance-related app declaration and Play Financial Features form confirmed in Play Console
- [ ] Review Crashlytics and Google Analytics default collection settings before shipping

**Critical:** A security feature existing as prototype source code is NOT proof it runs on every installed device. Likewise, a draft policy is not a substitute for an implemented data deletion path.
