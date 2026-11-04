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

 
// M421: authenticated, separately consented bank-SMS cloud extraction.
// Remains disabled until owner configures App Check, the Secret Manager key,
// legal/privacy review, chosen LLM and explicit WAFFRA_SMS_CLOUD_ENABLED.
const {defineSecret} = require('firebase-functions/params');
const {suggestFromBankSms} = require('./openrouter_sms_extractor.cjs');
const smsKey = defineSecret('WAFFRA_OPENROUTER_API_KEY');
function checkedSmsOwner(request) {
  const uid = request.auth?.uid;
  if (typeof uid !== 'string' || uid.length < 6 || uid.length > 128 ||
      uid.includes('/')) {
    throw new HttpsError('unauthenticated', 'Sign in required for cloud analysis.');
  }
  if (!request.app?.appId) {
    throw new HttpsError('permission-denied', 'Verified app required.');
  }
  return uid;
}
function cloudSmsEnabled() {
  if (process.env.WAFFRA_SMS_CLOUD_ENABLED !== 'true') {
    throw new HttpsError('failed-precondition',
      'Optional cloud SMS analysis is not enabled.');
  }
}
const smsOptions = {region: 'me-central2', enforceAppCheck: true,
  memory: '256MiB', maxInstances: 3, timeoutSeconds: 30};

exports.setWaffraSmsCloudConsent = onCall(smsOptions, async (request) => {
  cloudSmsEnabled();
  const uid = checkedSmsOwner(request);
  const choice = request.data;
  if (!choice || Object.keys(choice).length !== 2 ||
      choice.version !== 1 || typeof choice.enabled !== 'boolean') {
    throw new HttpsError('invalid-argument', 'Explicit consent choice required.');
  }
  await admin.firestore().collection('waffraSmsCloudConsents').doc(uid).set({
    enabled: choice.enabled, version: 1,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return {enabled: choice.enabled, version: 1};
});

exports.analyzeWaffraBankSms = onCall({...smsOptions, secrets: [smsKey]},
  async (request) => {
    cloudSmsEnabled();
    const uid = checkedSmsOwner(request);
    if (request.data?.cloudConsent !== true) {
      throw new HttpsError('permission-denied', 'Separate cloud SMS consent required.');
    }
    const firestore = admin.firestore();
    const consent = await firestore.collection('waffraSmsCloudConsents')
      .doc(uid).get();
    if (!consent.exists || consent.data()?.enabled !== true ||
        consent.data()?.version !== 1) {
      throw new HttpsError('permission-denied', 'Cloud SMS access is not enabled.');
    }
    const now = Date.now();
    const date = new Date(now).toISOString().slice(0, 10).replace(/-/g, '');
    const quota = firestore.collection('waffraSmsCloudRateLimits').doc(uid + '_' + date);
    const accepted = await firestore.runTransaction(async (tx) => {
      const doc = await tx.get(quota);
      const count = doc.exists ? doc.data().count || 0 : 0;
      const lastAt = doc.exists ? doc.data().lastAt || 0 : 0;
      if (count >= 30 || now - lastAt < 3000) return false;
      tx.set(quota, {count: count + 1, lastAt: now,
        expiresAt: admin.firestore.Timestamp.fromMillis(now + 35 * 86400000)},
      {merge: true});
      return true;
    });
    if (!accepted) {
      throw new HttpsError('resource-exhausted', 'Daily SMS analysis quota reached.');
    }
    try {
      return await suggestFromBankSms({
        data: request.data, enabled: true,
        apiKey: smsKey.value(), model: process.env.WAFFRA_SMS_LLM_MODEL || 'openai/gpt-4.1-mini',
      });
    } catch (_) {
      // Do not log the message, model response, merchant, account, or prompt.
      throw new HttpsError('failed-precondition',
        'Cloud SMS analysis could not verify this message.');
    }
  });
