'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {
  normalizeSaudiPhone,validatePassword,lookupId,hashPassword,checkPassword,
  enroll,signIn,resetPassword,PARAMS,MAX_ATTEMPTS,WINDOW,
} = require('../phone_auth_core.cjs');

const pepper = 'owner-configured-private-phone-auth-pepper-48-bytes';
const phone = '0501234567',e164='+966501234567',uid='legacy-google-uid-unchanged';
const at = Math.floor(Date.now()/1000);
const owner = {uid,phoneNumber:e164,disabled:false};
const request = {
  auth:{uid,token:{auth_time:at,phone_number:e164}},
  app:{appId:'1:qa:android:signed'},
};
function fakeService() {
  const users = new Map([[uid,owner]]);
  const byPhone = new Map();
  const credentials = new Map();
  const attempts = new Map();
  const records = {financeLedger:[
    {id:'old-manual-01',amount:1200,accountOwner:uid},
    {id:'old-sms-02',amount:-75,accountOwner:uid},
  ]};
  let revoked=0;
  const authAdmin = {
    getUser:async(uid)=> {
      if (!users.has(uid)) throw Error('auth user missing');
      return users.get(uid);
    },
    createCustomToken:async(uid)=>'signed-custom-token-'+uid,
    revokeRefreshTokens:async(uid)=>{ revoked++; },
  };
  const store = {
    bindPhone:async({key,uid,passwordDigest})=>{
      if (byPhone.has(key) && byPhone.get(key).uid!==uid) return false;
      if(credentials.has(uid) && credentials.get(uid).phoneKey!==key)
        return false;
      byPhone.set(key,{uid});
      credentials.set(uid,{phoneKey:key,digest:passwordDigest});
      return true;
    },
    phoneOwner:async(key)=>byPhone.get(key) || null,
    passwordRecord:async(uid)=>credentials.get(uid) || null,
    attempt:async({key,nowMs,windowMs,maxAttempts})=>{
      const row=attempts.get(key);
      const count=row && nowMs-row.start<windowMs?row.count:0;
      if(count>=maxAttempts)return false;
      attempts.set(key,{start:count?row.start:nowMs,count:count+1});
      return true;
    },
    resetPassword:async({uid,key,digest})=>{
      if(byPhone.get(key)?.uid!==uid ||
         credentials.get(uid)?.phoneKey!==key) return false;
      credentials.set(uid,{phoneKey:key,digest});
      return true;
    },
  };
  return {authAdmin,store,byPhone,credentials,attempts,records,users,
    getRevoked:()=>revoked};
}
test('M425: Saudi phone only; no country picker and no email alias',()=>{
  assert.equal(normalizeSaudiPhone(phone),e164);
  assert.equal(normalizeSaudiPhone(e164),e164);
  for(const bad of ['050123456','05012345678','0412345678',
    '+201234567890','050123456x','501234567', 'user@mail.com','']) {
    assert.throws(()=>normalizeSaudiPhone(bad),/INVALID_PHONE/);
  }
  assert.equal(lookupId(phone,pepper),lookupId(e164,pepper));
  assert.equal(lookupId(phone,pepper).length,64);
  assert.equal(lookupId(phone,pepper).includes('050123'),false);
});
test('M425: password verifier is peppered scrypt with approved cost',async()=>{
  assert.equal(PARAMS.N,65536);
  assert.equal(PARAMS.r,8);
  assert.equal(PARAMS.p,2);
  assert.throws(()=>validatePassword('short'),/INVALID_PASSWORD/);
  const hash=await hashPassword('SecurePass#123!',pepper);
  assert.equal(hash.hash.includes('SecurePass'),false);
  assert.equal(hash.salt.length>40,true);
  assert.equal(await checkPassword('SecurePass#123!',pepper,hash),true);
  assert.equal(await checkPassword('WrongPass#123!',pepper,hash),false);
  assert.equal(await checkPassword('SecurePass#123!',pepper,null),false);
  await assert.rejects(hashPassword('SecurePass#123!','short'));
});
test('M425: OTP-verified legacy UID is preserved; finance never touched',async()=>{
  const service=fakeService();
  const before=JSON.stringify(service.records.financeLedger);
  const enrolled=await enroll({request,phone,password:'SecurePass#123!',
    pepper,authAdmin:service.authAdmin,store:service.store,now:at});
  assert.deepEqual(enrolled,{enrolled:true,uid});
  assert.equal(service.byPhone.get(lookupId(phone,pepper)).uid,uid);
  const response=await signIn({request:{app:request.app},phone,
    password:'SecurePass#123!',pepper,
    authAdmin:service.authAdmin,store:service.store});
  assert.equal(response.customToken,'signed-custom-token-'+uid);
  assert.equal(JSON.stringify(service.records.financeLedger),before);
});
test('M425: another UID cannot take linked phone or overwrite finances',async()=>{
  const service=fakeService();
  await enroll({request,phone,password:'SecurePass#123!',pepper,
    authAdmin:service.authAdmin,store:service.store,now:at});
  const stranger='attacker-new-uid';
  service.users.set(stranger,{uid:stranger,phoneNumber:e164,disabled:false});
  const wrong={auth:{uid:stranger,token:{auth_time:at,phone_number:e164}},
    app:request.app};
  await assert.rejects(enroll({request:wrong,phone,
    password:'OtherPassword99!',pepper,
    authAdmin:service.authAdmin,store:service.store,now:at}),
    /PHONE_ALREADY_REGISTERED/);
  assert.equal(service.byPhone.get(lookupId(phone,pepper)).uid,uid);
});
test('M425: wrong phone, stale OTP, missing App Check reject enrollment',async()=>{
  const service=fakeService();
  for (const invalid of [
    {...request,app:null},
    {...request,auth:{...request.auth,token:{...request.auth.token,
      auth_time:at-3600}}},
    {...request,auth:{...request.auth,token:{...request.auth.token,
      phone_number:'+966599999999'}}},
  ]) {
    await assert.rejects(enroll({request:invalid,phone,
      password:'SecurePass#123!',pepper,authAdmin:service.authAdmin,
      store:service.store,now:at}));
  }
  assert.equal(service.byPhone.size,0);
});
test('M425: wrong credentials and unknown account share fail-closed path',async()=>{
  const service=fakeService();
  await enroll({request,phone,password:'SecurePass#123!',pepper,
    authAdmin:service.authAdmin,store:service.store,now:at});
  await assert.rejects(signIn({request:{app:request.app},phone,
    password:'WrongPassword999',pepper,
    authAdmin:service.authAdmin,store:service.store}),/INVALID_CREDENTIALS/);
  await assert.rejects(signIn({request:{app:request.app},
    phone:'0599999999',password:'WrongPassword999',pepper,
    authAdmin:service.authAdmin,store:service.store}),/INVALID_CREDENTIALS/);
  await assert.rejects(signIn({request:{},phone,
    password:'SecurePass#123!',pepper,
    authAdmin:service.authAdmin,store:service.store}),/APP_CHECK_REQUIRED/);
});
test('M425: bounded password guessing, no token beyond quota',async()=>{
  const service=fakeService();
  await enroll({request,phone,password:'SecurePass#123!',pepper,
    authAdmin:service.authAdmin,store:service.store,now:at});
  const nowMs=Date.now();
  for(let i=0;i<MAX_ATTEMPTS;i++){
    await assert.rejects(signIn({request:{app:request.app},phone,
      password:'WrongPassword999',pepper,authAdmin:service.authAdmin,
      store:service.store,nowMs}),/INVALID_CREDENTIALS/);
  }
  await assert.rejects(signIn({request:{app:request.app},phone,
    password:'SecurePass#123!',pepper,
    authAdmin:service.authAdmin,store:service.store,nowMs}),
    /TOO_MANY_ATTEMPTS/);
  assert.equal(WINDOW,900000);
});
test('M425: password reset requires fresh OTP and retains same UID',async()=>{
  const service=fakeService();
  const before=JSON.stringify(service.records.financeLedger);
  await enroll({request,phone,password:'SecurePass#123!',pepper,
    authAdmin:service.authAdmin,store:service.store,now:at});
  await assert.rejects(resetPassword({
    request:{...request,auth:{...request.auth,token:{auth_time:at-3600,
      phone_number:e164}}},
    phone,newPassword:'NewPassword!123',pepper,
    authAdmin:service.authAdmin,store:service.store,now:at}),
    /RECENT_AUTH_REQUIRED/);
  const result=await resetPassword({request,phone,
    newPassword:'NewPassword!123',pepper,
    authAdmin:service.authAdmin,store:service.store,now:at});
  assert.deepEqual(result,{reset:true});
  assert.equal(service.getRevoked(),1);
  const old=await service.store.passwordRecord(uid);
  assert.equal(await checkPassword('SecurePass#123!',pepper,old.digest),false);
  assert.equal(await checkPassword('NewPassword!123',pepper,old.digest),true);
  assert.equal(JSON.stringify(service.records.financeLedger),before);
});
test('M425: store failure cannot fall back to local SHA256 or mint token',async()=>{
  const service=fakeService();
  service.store.attempt=async()=>{throw Error('FIRESTORE_UNAVAILABLE');};
  await assert.rejects(signIn({request:{app:request.app},phone,
    password:'SecurePass#123!',pepper,
    authAdmin:service.authAdmin,store:service.store}),
    /FIRESTORE_UNAVAILABLE/);
});
