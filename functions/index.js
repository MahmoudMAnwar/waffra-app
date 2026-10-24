'use strict';

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const { verifyRequest, deleteOwnedAccount } = require('./account_deletion.cjs');

if (!admin.apps.length) admin.initializeApp();

// Explicitly disabled until server policy, customer service, data retention,
// complete client UX and Firestore Emulator tests are signed off.
// No GitHub workflow deploys Functions or flips this environment flag.
exports.deleteWaffraAccount = onCall({
  region: 'me-central2',
  timeoutSeconds: 180,
  memory: '512MiB',
  maxInstances: 3,
  enforceAppCheck: false, // App Check rollout is separately gated.
}, async (request) => {
  if (process.env.WAFFRA_ACCOUNT_DELETION_ENABLED !== 'true') {
    throw new HttpsError('failed-precondition',
      'Account deletion service is not enabled.');
  }
  let uid;
  try {
    uid = verifyRequest(
      request.data,
      request.auth,
      Math.floor(Date.now() / 1000),
    );
  } catch (e) {
    const name = e.message;
    const type = name === 'UNAUTHENTICATED' ? 'unauthenticated' :
      name === 'RECENT_LOGIN_REQUIRED' ? 'failed-precondition' :
      'invalid-argument';
    throw new HttpsError(type, 'Fresh authentication and explicit confirmation required.');
  }
  try {
    const firestore = admin.firestore();
    return await deleteOwnedAccount({
      uid,
      firestore: {
        collection: (name) => firestore.collection(name),
        recursiveDelete: (doc) => firestore.recursiveDelete(doc),
        serverTimestamp: () => admin.firestore.FieldValue.serverTimestamp(),
      },
      authAdmin: admin.auth(),
    });
  } catch (_) {
    // Never log exception contents; SDK errors can contain remote data.
    throw new HttpsError('internal',
      'Secure account deletion was not completed. Retry or contact support.');
  }
});
