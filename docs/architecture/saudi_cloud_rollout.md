# Waffra Saudi-first optional cloud sync: activation checklist

**Status:** BLOCKED by account-owned provisioning and E2EE/recovery implementation. No remote financial upload is enabled. This document is not proof of Saudi PDPL compliance.

## Owner-owned Firebase console steps (can be performed from a phone)

1. Sign in to https://console.firebase.google.com using the **owner's own account**. Never provide passwords, OTPs or private Firebase service account keys in a GitHub issue, PR or chat.
2. Open existing Waffra project (`firebase/google-services.json` currently identifies project `waffra-app`) and navigate to **Build > Firestore Database**.
3. **Before** clicking Create database, check whether any Firestore database already exists and the location of its default database. Existing location is not directly changeable. If a default DB is in another region, stop and decide between a supported named database or isolated Saudi-region Firebase project before continuing.
4. For an approved new database choose **Dammam / me-central2**, confirm the actual database ID, **Standard/Native** mode as appropriate, applicable billing and service location. Use **production/locked rules**, not open test rules.
5. Deploy and emulator-test a reviewed owner-scoped rule set. The checked-in `firebase/firestore.rules` is currently **deny-all by design**; it must stay deny-all until the sync client, E2EE/recovery and rules tests pass. Do not deploy a rule allowing all signed-in users to access every vault.
6. Confirm Auth, crash reporting, analytics, receipt storage, support, backups and service processors separately. Region of Firestore does not assert geography of every processor or provide automatic PDPL compliance.
7. Set billing alerts and a budget. Alerts are not hard spend caps; monitor operations and abuse separately.

## Explicit opt-in specification

On Account screen, off by default: **'Enable encrypted cloud backup and device sync'**. Consent notice must state exactly what is uploaded, service locations, encryption/recovery model, how to disable and delete cloud data, and whether the user can access it on a replacement phone.

Never turn this on automatically after Google sign-in, backup export or local migration. A verified matching Firebase UID must be linked by the user to the current local vault. Two signed-in accounts on one device must never share a financial vault.

## Key and recovery requirements

- Offline ledger uses its own at-rest encrypted SQLite key protected by OS secure storage; this device-only key must NOT be stored in Firestore or analytics.
- Cloud financial sync needs **a separately defined end-to-end encryption key** with a secure cross-device recovery mechanism (e.g., a recovery secret provided by the user). Firebase Auth credentials alone are not an E2EE recovery key.
- Each record must be encrypted/authenticated on the client before upload, using a random nonce, authenticated envelope format, version and associated vault/record identity. Sensitive titles, amounts, SMS data and receipts must never appear in plaintext metadata.
- Test wrong key, key rotation, lost recovery key, reinstallation, replacement device, compromised/tampered cloud data and full account deletion before launch. No silent destructive resets.
- Normal local snapshots must not be imported into someone else's Firestore vault; require explicit approval and tested deduplication/conflict policy.

## Local implementation gates

1. Android emulator and physical-device crypto/DB tests.
2. iOS simulator and physical-device crypto/DB tests.
3. Normalized database import parity for entries/categories/goals/recurring/challenges/trash/postponements/SMS hashes/merchant rules/receipts.
4. A single atomic local write path for every save from UI, SMS, recurring automation, widget and reports; no uncoordinated dual writes.
5. Guarded cutover with migration journal, encrypted backup, restart/retry and rollback/recovery.
6. UI consent + account-vault mapping + encrypted record sync with durable outbox.
7. Firestore emulator authorization/rule tests + same-user and cross-user isolation.
8. Saudi legal/privacy and marketplace policy review; then measured rollout.

## Current status

- Encrypted staging and preflight on GitHub branch are prototypes, **not used** by the shipping UI.
- Cloud eligibility gate is a pure, read-only decision helper; it doesn't grant access or call Firebase.
- `firebase/firestore.rules` denies all access until a later reviewed deployment.
- No Firestore database has been created or verified by these GitHub code changes.
