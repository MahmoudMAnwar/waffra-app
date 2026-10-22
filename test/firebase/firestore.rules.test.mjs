import { before, after, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment, assertFails, assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  getDoc, setDoc, doc, deleteDoc, serverTimestamp,
} from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-waffra-rules-ci',
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});
beforeEach(async () => {
  await env.clearFirestore();
});
after(async () => {
  if (env) await env.cleanup();
});

function vault(ownerUid) {
  return {
    ownerUid,
    schemaVersion: 1,
    syncEnabled: true,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
}
function encryptedRecord(extra = {}) {
  return {
    kind: 'entry',
    ciphertext: 'a-base64-ciphertext-string',
    nonce: 'nonce-b64',
    mac: 'authentication-tag-b64',
    encryptionVersion: 1,
    deviceId: 'device-pseudonym',
    mutationId: 'mutation-0001',
    localVersion: 1,
    updatedAt: serverTimestamp(),
    deleted: false,
    ...extra,
  };
}
const path = 'users/alice/vaults/vault-123';
const recordPath = path + '/records/tx-01';

test('only Alice can create and read her encrypted vault', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  const bob = env.authenticatedContext('bob').firestore();
  await assertSucceeds(setDoc(doc(alice, path), vault('alice')));
  const data = await assertSucceeds(getDoc(doc(alice, path)));
  assert.equal(data.data().ownerUid, 'alice');
  await assertFails(getDoc(doc(bob, path)));
  await assertFails(setDoc(doc(bob, path), vault('alice')));
});

test('unauthenticated user can neither create a vault nor read an existing one', async () => {
  const anon = env.unauthenticatedContext().firestore();
  const alice = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(anon, path), vault('alice')));
  await assertSucceeds(setDoc(doc(alice, path), vault('alice')));
  await assertFails(getDoc(doc(anon, path)));
});

test('no record can be created without a verified parent vault', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(alice, recordPath), encryptedRecord()));
});

test('encrypted records work, but Bob cannot read, write or delete them', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  const bob = env.authenticatedContext('bob').firestore();
  await assertSucceeds(setDoc(doc(alice, path), vault('alice')));
  await assertSucceeds(setDoc(doc(alice, recordPath), encryptedRecord()));
  await assertSucceeds(getDoc(doc(alice, recordPath)));
  await assertFails(getDoc(doc(bob, recordPath)));
  await assertFails(setDoc(doc(bob, recordPath), encryptedRecord()));
  await assertFails(deleteDoc(doc(bob, recordPath)));
  await assertFails(deleteDoc(doc(alice, recordPath)));
});

test('finance plaintext, foreign fields and invalid encryption versions are denied', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  await assertSucceeds(setDoc(doc(alice, path), vault('alice')));
  await assertFails(setDoc(doc(alice, recordPath),
    encryptedRecord({ amount_minor: 12345 })));
  await assertFails(setDoc(doc(alice, recordPath),
    encryptedRecord({ description: 'private merchant name' })));
  await assertFails(setDoc(doc(alice, recordPath),
    encryptedRecord({ encryptionVersion: 0 })));
  await assertFails(setDoc(doc(alice, recordPath),
    encryptedRecord({ ciphertext: 'x'.repeat(710000) })));
});

test('vault metadata cannot spoof owner or add unapproved fields', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(alice, path), vault('bob')));
  await assertFails(setDoc(doc(alice, path),
    { ...vault('alice'), bankAccount: 'never-allowed' }));
});

test('a mutation with a lower local version cannot overwrite a newer one', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  await assertSucceeds(setDoc(doc(alice, path), vault('alice')));
  await assertSucceeds(setDoc(doc(alice, recordPath),
    encryptedRecord({ localVersion: 10 })));
  await assertFails(setDoc(doc(alice, recordPath),
    encryptedRecord({ localVersion: 2, mutationId: 'older' })));
});

test('equal-version overwrite and replay cannot change financial ciphertext', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  await assertSucceeds(setDoc(doc(alice, path), vault('alice')));
  await assertSucceeds(setDoc(doc(alice, recordPath), encryptedRecord()));
  await assertFails(setDoc(doc(alice, recordPath),
    encryptedRecord({ ciphertext: 'forged-replay', mutationId: 'mutation-0002' })));
  await assertFails(setDoc(doc(alice, recordPath),
    encryptedRecord({ localVersion: 1, mutationId: 'mutation-0002' })));
  const current = await getDoc(doc(alice, recordPath));
  assert.equal(current.data().ciphertext, encryptedRecord().ciphertext);
});

test('one sequential revision advances but a second same-version writer conflicts', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  await assertSucceeds(setDoc(doc(alice, path), vault('alice')));
  await assertSucceeds(setDoc(doc(alice, recordPath), encryptedRecord()));
  await assertSucceeds(setDoc(doc(alice, recordPath),
    encryptedRecord({
      localVersion: 2, mutationId: 'mutation-device-a',
      ciphertext: 'ciphertext-from-device-a',
    })));
  await assertFails(setDoc(doc(alice, recordPath),
    encryptedRecord({
      localVersion: 2, mutationId: 'mutation-device-b',
      ciphertext: 'ciphertext-from-device-b',
    })));
  const winner = await getDoc(doc(alice, recordPath));
  assert.equal(winner.data().localVersion, 2);
  assert.equal(winner.data().ciphertext, 'ciphertext-from-device-a');
});

test('version jumps and deleting either vault or finance record are blocked', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  await assertSucceeds(setDoc(doc(alice, path), vault('alice')));
  await assertSucceeds(setDoc(doc(alice, recordPath), encryptedRecord()));
  await assertFails(setDoc(doc(alice, recordPath),
    encryptedRecord({
      localVersion: 999, mutationId: 'jump-ahead',
    })));
  await assertFails(deleteDoc(doc(alice, recordPath)));
  await assertFails(deleteDoc(doc(alice, path)));
});

test('disabled sync parent refuses new encrypted financial uploads', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  await assertSucceeds(setDoc(doc(alice, path),
    { ...vault('alice'), syncEnabled: false }));
  await assertFails(setDoc(doc(alice, recordPath), encryptedRecord()));
});
