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


// M425 secure Saudi phone/password candidate; disabled until Firebase App
// Check, real SMS OTP, owner billing, physical-device migration and QA pass.
const {defineSecret} = require('firebase-functions/params');
const {enroll,signIn,resetPassword} = require('./phone_auth_core.cjs');
const {createPhoneAuthStore} = require('./phone_auth_store.cjs');
const phonePasswordPepper = defineSecret('WAFFRA_PHONE_PASSWORD_PEPPER');
const phoneOptions = {
  region:'me-central2',
  memory:'1GiB',
  timeoutSeconds:40,
  concurrency:2,
  maxInstances:3,
  enforceAppCheck:true,
  secrets:[phonePasswordPepper],
};
function requirePhoneAuthService() {
  if (process.env.WAFFRA_PHONE_AUTH_ENABLED !== 'true') {
    throw new HttpsError('failed-precondition',
      'Verified phone authentication is not enabled.');
  }
}
function authDependencies() {
  return {
    authAdmin:admin.auth(),
    store:createPhoneAuthStore(admin.firestore()),
    pepper:phonePasswordPepper.value(),
  };
}
exports.waffraEnrollPhonePassword = onCall(phoneOptions,async(request)=>{
  requirePhoneAuthService();
  try {
    const result = await enroll({
      request,phone:request.data?.phone,password:request.data?.password,
      ...authDependencies(),
    });
    return {enrolled:result.enrolled};
  } catch (_) {
    // Keep the user's phone and password out of logs.
    throw new HttpsError('failed-precondition',
      'Verified phone ownership or registration is unavailable.');
  }
});
exports.waffraSignInPhonePassword = onCall(phoneOptions,async(request)=>{
  requirePhoneAuthService();
  try {
    return await signIn({
      request,phone:request.data?.phone,password:request.data?.password,
      ...authDependencies(),
    });
  } catch (_) {
    // One response for invalid credentials and unknown numbers. Rate limiting
    // is enforced by the atomic store before checking passwords.
    throw new HttpsError('permission-denied',
      'Unable to sign in. Verify details or try again later.');
  }
});
exports.waffraResetPhonePassword = onCall(phoneOptions,async(request)=>{
  requirePhoneAuthService();
  try {
    return await resetPassword({
      request,phone:request.data?.phone,
      newPassword:request.data?.newPassword,...authDependencies(),
    });
  } catch (_) {
    throw new HttpsError('failed-precondition',
      'Recent verified phone authentication is required to reset password.');
  }
});
