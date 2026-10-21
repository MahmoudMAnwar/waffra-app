# M54 — Android emulator: full offline finance copy and receipt audit

This Android instrumented test uses only **synthetic SharedPreferences** and test-generated receipts in a temporary app-owned directory.

It creates an isolated SQLCipher finance vault, copies the exact historical transactions, saving goal, SMS deduplication hashes and budget under the same app/widget writer lock, runs the separate M53 receipt byte audit, and verifies **every receipt SHA-256 digest**.

It then closes and reopens the database and confirms records, amounts, goals, receipt references, profile preferences and absent activation markers all remain unchanged. Finally it deliberately deletes a synthetic receipt and confirms the auditor **fails closed** rather than claiming the encrypted finance migration has completed.

Registered as the final emulator step in the existing encrypted DB integration workflow. This is an end-to-end test of offline **staging and validation**, not an actual source switch, uploaded receipt migration or release APK. No production user data, Firebase account, bank access or cloud storage is touched.

## Before production cutover

Still required: secure key recovery and backup, actual byte-for-byte receipt installation into SQLCipher or recoverable copied sandbox, updating all finance UI/Android widget/SMS writers to a single authoritative source, durable marker journal and rollback, complete UI/analytics/PDF parity, and final Android APK/device acceptance tests. Firebase can stay configured but must not control local data activation.
