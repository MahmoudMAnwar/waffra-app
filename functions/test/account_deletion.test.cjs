'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { verifyRequest, deleteOwnedAccount, CONFIRM } =
  require('../account_deletion.cjs');

const now = 1792680000;
const uid = 'synthetic-owner-only';
function actor(overrides = {}) {
  return {
    uid,
    token: { auth_time: now - 60 },
    ...overrides,
  };
}

test('M107 requires authenticated same-account deletion and exact consent', () => {
  assert.equal(verifyRequest({ confirm: CONFIRM }, actor(), now), uid);
  for (const data of [null, {}, { confirm: 'yes' },
    { confirm: CONFIRM, ownerUid: 'other' }]) {
    assert.throws(() => verifyRequest(data, actor(), now));
  }
  assert.throws(() => verifyRequest({ confirm: CONFIRM }, null, now));
  assert.throws(() => verifyRequest({ confirm: CONFIRM },
    actor({ uid: 'other/user' }), now));
});

test('M107 old login cannot delete user even with a valid ID token', () => {
  for (const token of [
    { auth_time: now - 301 },
    { auth_time: now + 100 },
    { auth_time: 'invalid' },
    {},
  ]) {
    assert.throws(() => verifyRequest({ confirm: CONFIRM },
      actor({ token }), now), /RECENT_LOGIN_REQUIRED/);
  }
});

function fakeServer({ shouldFail = false, userMissing = false } = {}) {
  const calls = [];
  const firestore = {
    serverTimestamp: () => 'server-time',
    collection: (name) => ({
      doc: (id) => ({ collection: name, id, set: async (data) => {
        calls.push('write:' + name + ':' + id + ':' + data.status);
      } }),
    }),
    recursiveDelete: async (doc) => {
      calls.push('recursive:' + doc.collection + ':' + doc.id);
      if (shouldFail) throw new Error('synthetic-failure');
    },
  };
  const authAdmin = {
    deleteUser: async (value) => {
      calls.push('auth:' + value);
      if (userMissing) {
        const error = new Error('already-deleted');
        error.code = 'auth/user-not-found';
        throw error;
      }
    },
  };
  return { calls, firestore, authAdmin };
}

test('M107 deletion always tombstones, recursively deletes, then removes Auth',
  async () => {
    const server = fakeServer();
    assert.deepEqual(
      await deleteOwnedAccount({ uid, ...server }),
      { deleted: true },
    );
    assert.deepEqual(server.calls, [
      'write:accountDeletionRequests:synthetic-owner-only:deleting',
      'recursive:users:synthetic-owner-only',
      'auth:synthetic-owner-only',
      'write:accountDeletionRequests:synthetic-owner-only:completed',
    ]);
  });

test('M107 outage retains tombstone, does not delete Auth or report success',
  async () => {
    const server = fakeServer({ shouldFail: true });
    await assert.rejects(deleteOwnedAccount({ uid, ...server }));
    assert.deepEqual(server.calls, [
      'write:accountDeletionRequests:synthetic-owner-only:deleting',
      'recursive:users:synthetic-owner-only',
    ]);
  });

test('M107 retried deletion is idempotent if Firebase Auth is already absent',
  async () => {
    const server = fakeServer({ userMissing: true });
    assert.deepEqual(
      await deleteOwnedAccount({ uid, ...server }),
      { deleted: true },
    );
    assert.equal(server.calls.at(-1),
      'write:accountDeletionRequests:synthetic-owner-only:completed');
  });
