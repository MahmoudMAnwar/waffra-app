'use strict';

// Pure security boundary. No Firebase credentials, tokens, finance data, or
// exception text may be written to logs. Backend owns deletion permissions.
const CONFIRM = 'DELETE_WAFFRA_ACCOUNT';
const RECENT_AUTH_SECONDS = 300;

function verifyRequest(input, auth, nowSeconds) {
  if (!auth || typeof auth.uid !== 'string' || !auth.uid ||
      auth.uid.includes('/') || auth.uid.length > 128) {
    throw new Error('UNAUTHENTICATED');
  }
  if (!input || Object.keys(input).length !== 1 ||
      input.confirm !== CONFIRM) {
    throw new Error('CONFIRMATION_REQUIRED');
  }
  const loginTime = Number(auth.token?.auth_time);
  if (!Number.isSafeInteger(loginTime) || loginTime < 1 ||
      nowSeconds - loginTime < 0 ||
      nowSeconds - loginTime > RECENT_AUTH_SECONDS) {
    throw new Error('RECENT_LOGIN_REQUIRED');
  }
  return auth.uid;
}

// Idempotent attempt: commit a tombstone BEFORE deleting finance,
// recursively remove child collections, then delete login credentials.
// Keeping the tombstone after success prevents a still-cached auth token on
// a second phone from resurrecting a financial vault.
async function deleteOwnedAccount({ uid, firestore, authAdmin }) {
  const doc = firestore.collection('accountDeletionRequests').doc(uid);
  await doc.set({
    status: 'deleting',
    updatedAt: firestore.serverTimestamp(),
  }, { merge: true });
  // The Firestore parent+all descendants must be removed. .delete() of
  // /users/{uid} alone would strand encrypted child finance records.
  await firestore.recursiveDelete(
    firestore.collection('users').doc(uid),
  );
  try {
    await authAdmin.deleteUser(uid);
  } catch (error) {
    if (error?.code !== 'auth/user-not-found') throw error;
  }
  await doc.set({
    status: 'completed',
    updatedAt: firestore.serverTimestamp(),
  }, { merge: true });
  return { deleted: true };
}

module.exports = { CONFIRM, verifyRequest, deleteOwnedAccount };
