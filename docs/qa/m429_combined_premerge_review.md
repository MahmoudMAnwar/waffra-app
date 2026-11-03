# M429 — Combined QA release candidate / NOT MERGED
Includes local Saudi phone/password, non-OTP legacy local migration, mandatory
device biometrics, standing first-run SMS/cloud consent, Cloudflare App Check
signed attestation and strictly free-only OpenRouter routing with rate limits.
The existing finance journal, backup and SQLCipher are unchanged.
Source-diff boundary guard for lib/main.dart was verified before this commit.

Do not deploy to production or hand this APK to family until all exact-head
CI checks pass, the cloud Worker is configured on a distinct staging service,
sideloaded Play Integrity App Check succeeds on signed Android, and encrypted
finance/goal/budget/attachment backup parity is demonstrated on two devices.
App Check authenticates app integrity, not the actual owner of a mobile number.

## M432 — owner QA signed APK staging launch gate

PR #354's 40 GitHub Actions workflows passed on original SHA `b7fe94bc033e473bd929bd903285b8d074ddbf63`. CI pass is not a signed APK, actual phone test or data migration proof.

Manual `workflow_dispatch` on `main` with `sms_staging_worker=true` embeds only the public Cloudflare endpoint `https://waffra-sms-appcheck-staging.mahmoudmanwar159.workers.dev/analyze` in the signed **APK**, with all OpenRouter keys remaining only in Cloudflare Secrets. Default main-push APK and every AAB build keep SMS cloud disabled. Requests still require installation-wide opt-in and Firebase App Check.

Expected release-signing SHA-256: `89:4C:43:6D:C4:27:0D:46:81:57:07:A2:91:47:70:9E:89:CD:42:D4:0F:BF:5D:3A:E2:41:04:29:3B:03:AE:8C`. The Firebase App Check console must register this exact fingerprint, not merely any registered SHA-256. The worker's 401 denial of unattested requests proves rejection only; it does not prove signed Android client attestation or actual OpenRouter extraction.

Do not merge this draft or update a data-bearing family device before signed-APK owner acceptance and encrypted backup/finance/goal/budget/attachment migration parity have been verified. Initial staging SMS tests should use synthetic financial messages and a disposable QA profile, subject to cross-border privacy approval and Google Play SMS permission policy.

## M433 — bank SMS from activation month, review-only safety gate

- First opt-in records the first day of that month as a local, sticky calendar cutoff. Only received SMS from that month enter the bounded history query; new SMS enter through the receiver.
- Intake is encrypted using Android Keystore; the 100-candidate queue and a chronological cursor permit importing later batches after earlier messages are reviewed or ignored. This can require tapping Refresh in Home; it is not an unbounded scrape.
- ALL automatic analysis and financial posting are disabled by `WaffraAutoSmsAutoPoster.reviewOnly`. A notification is sent for each new qualifying financial SMS at most once; historical messages do not flood notifications. The locked phone only sees private review wording.
- Home has a persistent "Transactions requiring review" card with pending count, scrollable per-SMS selection and a manual confirmation flow. The existing SMS editor offers active budgets or an explicit unlinked choice with warning before the user confirms a save.
- Release blockers: Google Play SMS access policy; signed Android test of permissions, month boundaries and duplicate prevention; restoring previous owner data; App Check/OpenRouter accuracy for explicitly reviewed messages; two physical-device acceptance. No production cutover or main merge is claimed.

## M434 — per-sender SMS review list and saved transaction provenance

The Home review inbox now groups pending encrypted messages by the actual Android SMS sender. Group cards show sender name and count; selecting one opens its messages newest first with an explicit per-message review action. Sender grouping is case-insensitive but does not silently claim a sender is a verified bank or associate a manual transaction with a bank. On Back, the selection returns to the sender groups.

Persisted entries retain their `MoneyEntry.sourceType`. Both compact transaction lists and the transaction details screen visibly distinguish `sms` = "رسالة بنكية (SMS)" and `manual` = "إدخال يدوي". Receipt/goal-due entries are separate, and legacy or unknown entries are expressly marked as source unverified. An original SMS is opened only from its independently protected finance vault. A manual entry clearly states no original SMS exists. No ledger schema/finance data conversion was introduced.

Release remains blocked on exact-head CI, month-bounded import and sender count tests, signed hardware back-navigation/RTL checks, and data migration parity. Grouping only covers the **pending review SMS inbox**, not historical saved-transaction grouping by sender, because the older finance schema does not contain a verified sender on each saved transaction.

M434 follow-up: transaction edit form now also presents the immutable saved sourceType with a manual/SMS distinction. Encrypted originals remain readable only through the separately gated details viewer; there is no guessing or automatic provenance relabeling.
