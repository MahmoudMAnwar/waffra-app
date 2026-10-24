# Saudi Firestore opt-in sync: deployment gate

**Not provisioned. No financial data is uploaded, and no app code enables sync.**

## User-owned Firebase setup

1. Connect the user's own Firebase project (existing Google Auth project preferred).
2. Inspect existing Firestore databases and locations. Database location cannot
   be changed in place; do **not** assume existing default is in Saudi Arabia.
3. For a fresh database, explicitly select **Dammam `me-central2`** only after
   verifying current Firestore support, pricing, billing, SDK compatibility and
   PDPL/security obligations. If an existing database is elsewhere, choose
   a supported new database or an explicit migration plan; never move it
   silently or promise all Firebase/Auth/diagnostic data stays in Dammam.
4. Use separate Firebase staging and production projects / identities. Verify
   minimal service account IAM and rules deny cross-user and unauthenticated
   reads/writes.
5. Run the Firestore Security Rules emulator tests before deploying. No public
   `allow read, write: if true` or `request.auth != null` wildcard policies.
6. Deploy `firestore.rules` and `firestore.indexes.json` to **staging first**
   only after user approval. Production deployment requires a separate sign-off.
7. Cloud docs carry only *client-encrypted payloads* and routing metadata.
   Keys/passphrases, SMS bodies, receipt paths and plaintext transaction amounts
   must never be sent to Firestore. User must enable sync explicitly, with
   encryption recovery choices explained.
8. Missing connection or E2EE recovery design is a release blocker. Do not
   install the Firestore Flutter dependency or add automatic startup sync
   until both are tested and approved.

## Firebase Auth != Firestore

Google Auth is currently enabled for login. It does not create Firestore,
provide a data residency guarantee, encrypt user ledger end-to-end, or sync
records across phones. Sync remains disabled until all release gates pass.

## Security rules scope

- Only a signed-in user can access their own vault path.
- Vault metadata is limited to ownership, version, consent flag and timestamps.
- Records must use approved kinds and fields and contain ciphertext, nonce, tag
  and version; plaintext fields such as amounts, categories or descriptions
  are not allowed.
- A deleted vault document is not automatically cascaded to child records.
  A properly tested export/delete workflow must recursively remove records,
  respect revocation and prove deletion before app release.
- Rules protect only Firestore; Firebase Authentication, crash reporting,
  Analytics, file storage and any external processors need independent review.
- Deletion tombstones, conflicts, outbox idempotency, and cross-device E2EE
  key recovery must be designed and tested before cloud launch.
