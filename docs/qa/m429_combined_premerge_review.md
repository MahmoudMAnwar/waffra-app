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
