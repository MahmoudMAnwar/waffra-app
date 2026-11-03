'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {createPhoneAuthStore} = require('../phone_auth_store.cjs');

function fakeFirestore() {
  const db = new Map();
  const changed = [];
  function ref(collection,id) {
    return {collection,id, key:collection + '/' + id};
  }
  return {
    db, changed,
    collection:(collection)=>({
      doc:(id)=>({
        ...ref(collection,id),
        get:async()=>{
          const value=db.get(ref(collection,id).key);
          return {exists:value!=null,data:()=>value};
        },
      }),
    }),
    runTransaction:async(fn)=>{
      const writes = [];
      const tx = {
        get:async(reference)=>{
          const value=db.get(reference.key);
          return {exists:value!=null,data:()=>value};
        },
        set:(reference,value)=>writes.push([reference,value]),
      };
      const out = await fn(tx);
      for(const [reference,value] of writes) {
        db.set(reference.key,value);
        changed.push(reference.collection);
      }
      return out;
    },
  };
}
const phoneKey = 'a'.repeat(64);
test('M425 Firestore: exact UID owns the phone and never overlaps another',async()=>{
  const firestore=fakeFirestore();
  const store=createPhoneAuthStore(firestore);
  assert.equal(await store.bindPhone({
    key:phoneKey,uid:'old-google-uid',
    passwordDigest:{hash:'secret-not-client-side'},at:12,
  }),true);
  assert.equal((await store.phoneOwner(phoneKey)).uid,'old-google-uid');
  assert.equal((await store.passwordRecord('old-google-uid')).phoneKey,phoneKey);
  assert.equal(await store.bindPhone({key:phoneKey,uid:'attacker-uid',
    passwordDigest:{hash:'attacker'},at:13}),false);
  assert.equal((await store.phoneOwner(phoneKey)).uid,'old-google-uid');
  assert.deepEqual(
    [...new Set(firestore.changed)].sort(),
    ['waffraPhoneBindings','waffraPhoneCredentials']);
  assert.equal(firestore.changed.includes('financeLedger'),false);
});
test('M425 Firestore: linked UID cannot silently switch to a second mobile',async()=>{
  const firestore=fakeFirestore(),store=createPhoneAuthStore(firestore);
  assert.equal(await store.bindPhone({
    key:phoneKey,uid:'legacy-owner',passwordDigest:{hash:'original'},at:1,
  }),true);
  assert.equal(await store.bindPhone({
    key:'b'.repeat(64),uid:'legacy-owner',
    passwordDigest:{hash:'new'},at:2,
  }),false);
  assert.equal((await store.phoneOwner(phoneKey)).uid,'legacy-owner');
  assert.equal(await store.phoneOwner('b'.repeat(64)),null);
});
test('M425 Firestore: password reset requires exact matching owner binding',async()=>{
  const firestore=fakeFirestore(),store=createPhoneAuthStore(firestore);
  await store.bindPhone({
    key:phoneKey,uid:'old-owner',passwordDigest:{hash:'previous'},at:1,
  });
  assert.equal(await store.resetPassword({
    uid:'attacker',key:phoneKey,digest:{hash:'evil'},at:2}),false);
  assert.equal((await store.passwordRecord('old-owner')).digest.hash,'previous');
  assert.equal(await store.resetPassword({
    uid:'old-owner',key:phoneKey,digest:{hash:'new'},at:2}),true);
  assert.equal((await store.passwordRecord('old-owner')).digest.hash,'new');
});
test('M425 Firestore: bound five-attempt limit, new window resets',async()=>{
  const firestore=fakeFirestore(),store=createPhoneAuthStore(firestore);
  for(let i=0;i<5;i++){
    assert.equal(await store.attempt({
      key:phoneKey,nowMs:100000+i,windowMs:900000,maxAttempts:5,
    }),true);
  }
  assert.equal(await store.attempt({
    key:phoneKey,nowMs:100005,windowMs:900000,maxAttempts:5,
  }),false);
  assert.equal(await store.attempt({
    key:phoneKey,nowMs:100000+900001,windowMs:900000,maxAttempts:5,
  }),true);
});
test('M425 Firestore: invalid UID cannot be used as a document path',async()=>{
  const firestore=fakeFirestore(),store=createPhoneAuthStore(firestore);
  assert.equal(await store.passwordRecord('../attacker'),null);
  assert.equal(await store.passwordRecord(''),null);
  assert.equal(await store.passwordRecord('a'.repeat(129)),null);
});
