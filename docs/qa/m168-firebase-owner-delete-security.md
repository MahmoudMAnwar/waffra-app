# M168 — Firebase owner-only rules and account-deletion staging

Reference source: [PR #165](https://github.com/MahmoudMAnwar/waffra-app/pull/165) at `0242b54d1e77f1539eef3fa12d77e06fbc9eeabf`. This PR targets the integration branch only.

## Implemented
- Emulated attacker/scoped-client test: deleting a user's account tombstone blocks BOTH the original and second cached-UID phone from reading/writing/creating cloud records.
- Client cannot create, replace or delete the privileged account-deletion request; unrelated signed-in owner keeps access to own encrypted vault.
- Read-only audit enforces owner-scoped Firestore rule, default-off callable release flag, explicit reauthentication and backend-confirmed success.

## Existing components retained
- Firestore rules reject plaintext finance fields, unauthorized owners, physical deletes and lost-update revisions; cloud envelope is intended E2EE-only.
- `lib/waffra_account_deletion.dart` has a two-step, recently reauthenticated Firebase Google deletion flow, with `WAFFRA_ACCOUNT_DELETE_READY` default **false**. This is NOT deployed/usable production deletion until backend verified.
- Existing test/firebase suites cover tombstones, recovery envelopes, parent/child permissions and stale-device resurrection.

## Validate independently
`python3 scripts/qa/m168_firebase_delete_security_review.py`
`npm --prefix test/firebase install --no-audit --no-fund`
`./test/firebase/node_modules/.bin/firebase emulators:exec --only firestore --project demo-waffra-rules-ci 'npm --prefix test/firebase test'`

## Production release blockers
1. Verify actual privileged Cloud Function deployment, ownership, recent-login enforcement, recursive subcollection/storage deletion, idempotent retries and partial-failure behavior on test Firebase account.
2. Public HTTPS account-deletion page and bilingual user instructions actually published and tested.
3. Confirm repeated sign-in cannot resurrect deleted account with expired/stale tokens on two physical devices.
4. No deployment of `firestore.rules`, Firebase functions, real-account deletion, or source cutover performed here.
