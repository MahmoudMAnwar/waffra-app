# Waffra Account Deletion — Security Implementation Plan

**Not shipped. A real deletion flow is a production blocker.**

## Visible user experience (Arabic and English)
1. In Profile → Privacy and Security, add a clearly labeled **Delete Account and Data / حذف الحساب والبيانات** action.
2. Describe what is deleted: account identity, user-owned Firestore cloud vaults (if enabled), E2EE manifests/recovery envelopes and local finance/receipt backups where supported. Explicitly explain data retained due to legal obligations or server backups, if any, based on real policy.
3. Re-authenticate the signed-in Firebase user (fresh credential), require second confirmation, never ask for bank passwords or raw SMS.
4. Send an authenticated deletion request to a **privileged server-side** deletion coordinator, not merely a client-side Firestore delete. A personal client cannot reliably erase all server-side data by signing out and removing its own Auth record first.
5. Coordinator authorizes the caller, records no finance plaintext, deletes account-linked cloud vault objects/records/recovery envelopes (and any Storage uploads if used), handles transient errors/retries, and only then deletes the Firebase Auth account.
6. Remove local transaction/goal/receipt/backup data only according to the user's explicit choice and after securely verified remote deletion/intent state. Never reset local balances silently if cloud delete fails.
7. Display a verifiable successful/failed state. Define cancellation and contact support for unresolved cases.

## Public web path required by Play
Host a HTTPS page titled **Delete your Waffra account / حذف حساب وفرة** accessible without app login. It should identify Waffra/developer by real name, describe how to submit an authenticated deletion request and outline data deleted vs retained. **An email-only promise or a nonfunctional static mock form is NOT a verified deletion backend.** If an email-based request path is used, have a documented secure identity verification/reconciliation process and manual fulfillment SLA that meets Play requirements.

## Security acceptance
- [ ] No access to another user's Firebase UID/vault
- [ ] Deletion request cannot be replayed for a different account
- [ ] Token refresh/re-auth proof fresh, backend privileges correctly scoped
- [ ] Idempotent deletion, retry and interrupted-server recovery
- [ ] Child subcollections actually deleted (Firestore parent deletion alone is insufficient)
- [ ] Optional Firebase Storage receipts/backups enumerated and deleted
- [ ] No partial deletion shown as success
- [ ] Multi-device sync cannot resurrect a tombstoned deleted account
- [ ] Recovery code stops working after verified account deletion
- [ ] Test signed-out, offline, compromised token, two devices, partial Firestore outage
- [ ] The public deletion page and in-app button both work in the exact distributed app version
- [ ] Bilingual UI and accessible controls have a final user review

**Owner decisions still needed:** real publisher identity, support contact, HTTPS host, account-deletion service operator, lawful retention period and whether a user may delete only cloud data while keeping offline data.
