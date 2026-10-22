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
    encryptedRecord({ localVersion: 1 })));
  await assertSucceeds(setDoc(doc(alice, recordPath),
    encryptedRecord({ localVersion: 2, mutationId: 'newer' })));
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


test('M77 first encrypted document must start at revision one, even if owner is authenticated', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  await assertSucceeds(setDoc(doc(alice, path), vault('alice')));
  for (const version of [2, 3, 1000]) {
    await assertFails(setDoc(doc(alice, recordPath),
      encryptedRecord({ localVersion: version, mutationId: `first-${version}` })));
  }
  await assertSucceeds(setDoc(doc(alice, recordPath), encryptedRecord()));
  const confirmed = await getDoc(doc(alice, recordPath));
  assert.equal(confirmed.data().localVersion, 1);
});

test('M77 confirmed first writer wins an edit collision between two devices', async () => {
  const mobileA = env.authenticatedContext('alice').firestore();
  const mobileB = env.authenticatedContext('alice').firestore();
  await assertSucceeds(setDoc(doc(mobileA, path), vault('alice')));
  await assertSucceeds(setDoc(doc(mobileA, recordPath), encryptedRecord()));
  await assertSucceeds(setDoc(doc(mobileA, recordPath), encryptedRecord({
    localVersion: 2, mutationId: 'mobile-a-2',
    deviceId: 'mobile-a', ciphertext: 'encrypted-a-2',
  })));
  await assertFails(setDoc(doc(mobileB, recordPath), encryptedRecord({
    localVersion: 2, mutationId: 'mobile-b-2',
    deviceId: 'mobile-b', ciphertext: 'encrypted-b-2',
  })));
  const saved = await assertSucceeds(getDoc(doc(mobileB, recordPath)));
  assert.equal(saved.data().mutationId, 'mobile-a-2');
  assert.equal(saved.data().ciphertext, 'encrypted-a-2');
});

test('M77 disabling cloud sync freezes updates without erasing old ciphertext', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  const bob = env.authenticatedContext('bob').firestore();
  await assertSucceeds(setDoc(doc(alice, path), vault('alice')));
  await assertSucceeds(setDoc(doc(alice, recordPath), encryptedRecord()));
  const metadata = await getDoc(doc(alice, path));
  await assertSucceeds(setDoc(doc(alice, path), {
    ...vault('alice'),
    createdAt: metadata.data().createdAt,
    syncEnabled: false,
  }));
  await assertFails(setDoc(doc(alice, recordPath), encryptedRecord({
    localVersion: 2, mutationId: 'disabled-write',
  })));
  await assertFails(setDoc(doc(bob, recordPath), encryptedRecord({
    localVersion: 2, mutationId: 'foreign-write',
  })));
  const stillThere = await getDoc(doc(alice, recordPath));
  assert.equal(stillThere.data().mutationId, 'mutation-0001');
  await assertFails(deleteDoc(doc(alice, recordPath)));
});

test('M77 authenticated user cannot include raw SMS, IBAN or access tokens in cloud envelope', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  await assertSucceeds(setDoc(doc(alice, path), vault('alice')));
  for (const forbidden of ['rawSms', 'iban', 'bankCredentials', 'accessToken',
                            'receiptPath', 'accountNumber', 'fullName']) {
    await assertFails(setDoc(doc(alice, recordPath), encryptedRecord({
      [forbidden]: 'unapproved-plaintext',
    })));
  }
  await assertSucceeds(setDoc(doc(alice, recordPath), encryptedRecord()));
  const saved = await getDoc(doc(alice, recordPath));
  assert.deepEqual(
    Object.keys(saved.data()).sort(),
    ['kind', 'ciphertext', 'nonce', 'mac', 'encryptionVersion',
     'deviceId', 'mutationId', 'localVersion', 'updatedAt', 'deleted'].sort(),
  );
});

test('M77 old device cannot physically delete a tombstone or recreate the same document', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  await assertSucceeds(setDoc(doc(alice, path), vault('alice')));
  await assertSucceeds(setDoc(doc(alice, recordPath), encryptedRecord()));
  await assertSucceeds(setDoc(doc(alice, recordPath), encryptedRecord({
    localVersion: 2, mutationId: 'soft-delete', deleted: true,
    ciphertext: 'authenticated-encrypted-deletion',
  })));
  await assertFails(deleteDoc(doc(alice, recordPath)));
  await assertFails(setDoc(doc(alice, recordPath), encryptedRecord({
    localVersion: 1, mutationId: 'stale-undeletion', deleted: false,
  })));
  const remote = await getDoc(doc(alice, recordPath));
  assert.equal(remote.data().deleted, true);
  assert.equal(remote.data().localVersion, 2);
});


function wrappedRecovery(extra = {}) {
  return {
    schemaVersion: 1,
    vaultId: 'vault-123',
    keyVersion: 1,
    recoveryRevision: 1,
    wrappedKey: 'encrypted-256-bit-vault-key',
    nonce: 'encrypted-nonce-b64',
    mac: 'encrypted-aead-tag-b64',
    updatedAt: serverTimestamp(),
    ...extra,
  };
}

test('M98 owner can store only recovery-code-wrapped ciphertext; Bob is denied', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  const bob = env.authenticatedContext('bob').firestore();
  const recoveryPath = path + '/recovery/current';
  await assertSucceeds(setDoc(doc(alice, path), vault('alice')));
  await assertSucceeds(setDoc(doc(alice, recoveryPath), wrappedRecovery()));
  await assertSucceeds(getDoc(doc(alice, recoveryPath)));
  await assertFails(getDoc(doc(bob, recoveryPath)));
  await assertFails(setDoc(doc(bob, recoveryPath), wrappedRecovery()));
  await assertFails(setDoc(doc(alice, recoveryPath),
    wrappedRecovery({ recoveryCode: 'private-recovery-secret' })));
  await assertFails(setDoc(doc(alice, recoveryPath),
    wrappedRecovery({ rawVaultKey: 'private-vault-key' })));
  await assertFails(deleteDoc(doc(alice, recoveryPath)));
});

test('M98 encrypted recovery-key rotation permits only CAS revision + 1', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  const recoveryPath = path + '/recovery/current';
  await assertSucceeds(setDoc(doc(alice, path), vault('alice')));
  await assertFails(setDoc(doc(alice, recoveryPath),
    wrappedRecovery({ recoveryRevision: 2 })));
  await assertSucceeds(setDoc(doc(alice, recoveryPath), wrappedRecovery()));
  await assertSucceeds(setDoc(doc(alice, recoveryPath),
    wrappedRecovery({ recoveryRevision: 2, wrappedKey: 'rotated-key-ciphertext' })));
  await assertFails(setDoc(doc(alice, recoveryPath),
    wrappedRecovery({ recoveryRevision: 2, wrappedKey: 'stale-key-ciphertext' })));
  await assertFails(setDoc(doc(alice, recoveryPath),
    wrappedRecovery({ recoveryRevision: 4, wrappedKey: 'skip-ahead' })));
  await assertFails(setDoc(doc(alice, recoveryPath),
    wrappedRecovery({ recoveryRevision: 3, keyVersion: 2 })));
  const last = await getDoc(doc(alice, recoveryPath));
  assert.equal(last.data().recoveryRevision, 2);
});

test('M98 encrypted inventory is owner-only with no plaintext index', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  const bob = env.authenticatedContext('bob').firestore();
  const inventory = path + '/records/encrypted-index-hash';
  await assertSucceeds(setDoc(doc(alice, path), vault('alice')));
  await assertSucceeds(setDoc(doc(alice, inventory),
    encryptedRecord({ kind: 'manifest' })));
  await assertSucceeds(getDoc(doc(alice, inventory)));
  await assertFails(getDoc(doc(bob, inventory)));
  await assertFails(setDoc(doc(alice, inventory),
    encryptedRecord({ kind: 'manifest', records: ['private-id'] })));
  await assertFails(setDoc(doc(alice, inventory),
    encryptedRecord({ kind: 'manifest', amountMinor: 4500 })));
});
