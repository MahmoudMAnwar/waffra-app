import test from 'node:test';
import assert from 'node:assert/strict';
import {webcrypto} from 'node:crypto';
import {handleRequest} from './waffra_sms_worker.mjs';
import {verifyAppCheckToken} from './waffra_sms_appcheck.mjs';

const endpoint='https://waffra-sms-staging.example.workers.dev/analyze';
const sms='SAR 75.00 debited at TEST STORE';
const item={direction:'expense',amount:'75.00',currency:'SAR',
 description:'TEST STORE',source_quote:sms};
const env=()=>({
 OPENROUTER_API_KEY:'example-server-secret',
 FIREBASE_PROJECT_NUMBER:'1234567890',
 FIREBASE_ANDROID_APP_ID:'1:1234567890:android:aabbccddeeff',
 SMS_RATE_LIMITER:{limit:async()=>({success:true})},
 SMS_IP_LIMITER:{limit:async()=>({success:true})},
});
const request=(input={cloudConsent:true,text:sms},token='test.attestation')=>
 new Request(endpoint,{method:'POST',headers:{
  'X-Firebase-AppCheck':token,'content-type':'application/json',
  'CF-Connecting-IP':'192.0.2.14'},
  body:JSON.stringify(input)});
const verified=async()=> '1:1234567890:android:aabbccddeeff';

test('M427 configured health reports ready without secrets',async()=>{
 const response=await handleRequest(
  new Request(endpoint.replace('/analyze','/health')),env());
 const data=await response.json();
 assert.equal(response.status,200);
 assert.equal(data.ready,true);
 assert.equal(JSON.stringify(data).includes('example-server-secret'),false);
});
test('M427 rejects a missing or forged attestation before provider call',async()=>{
 const absent=await handleRequest(new Request(endpoint,{method:'POST'}),env());
 assert.equal(absent.status,401);
 const forged=await handleRequest(request(),env(),{
  verifyToken:async()=>{throw Error('invalid signature');}});
 assert.equal(forged.status,401);
});
test('M427 must have both quotas, provider key and FREE model only',async()=>{
 for(const variation of [
  {SMS_RATE_LIMITER:null},{SMS_IP_LIMITER:null},
  {OPENROUTER_API_KEY:null},{OPENROUTER_MODEL:'openai/gpt-4o'},
 ]){
  const response=await handleRequest(request(),{...env(),...variation},
   {verifyToken:verified});
  assert.equal(response.status,503);
 }
});
test('M427 explicit one-time consent affirmation and OTP guard',async()=>{
 let calls=0;
 for(const body of [{text:sms},{text:sms,cloudConsent:false},
  {cloudConsent:true,text:'OTP 1234 for SAR 75.00 purchase'},
  {cloudConsent:true,text:'SAR 75.00 purchase SA0380000000608010167519'}]){
  const response=await handleRequest(request(body),env(),{
   verifyToken:verified,
   fetchFn:async()=>{calls++;throw Error('unexpected provider');}});
  assert.equal(response.status,422);
 }
 assert.equal(calls,0);
});
test('M427 IP and token rates each fail closed',async()=>{
 for(const field of ['SMS_RATE_LIMITER','SMS_IP_LIMITER']){
  const e=env();e[field]={limit:async()=>({success:false})};
  const response=await handleRequest(request(),e,{verifyToken:verified});
  assert.equal(response.status,429);
 }
});
test('M427 request is free only, ZDR, and result needs user review',async()=>{
 let called=0;
 const response=await handleRequest(request(),env(),{
  verifyToken:verified,
  fetchFn:async(url,opts)=>{
   called++;
   assert.equal(url,'https://openrouter.ai/api/v1/chat/completions');
   assert.equal(opts.headers.authorization,'Bearer example-server-secret');
   const body=JSON.parse(opts.body);
   assert.equal(body.model,'openrouter/free');
   assert.equal(body.provider.zdr,true);
   assert.equal(body.provider.data_collection,'deny');
   assert.equal(body.messages[1].content,sms);
   return {ok:true,json:async()=>({
    choices:[{message:{content:JSON.stringify({transactions:[item]})}}]})};
  },
 });
 assert.equal(response.status,200);
 assert.equal(called,1);
 const data=await response.json();
 assert.equal(data.review_required,true);
 assert.equal(data.unverified,true);
 assert.equal(data.transactions[0].amount,'75.00');
});
test('M427 reject duplicate, hallucinated quote and provider error',async()=>{
 for(const rows of [[item,item],[{...item,source_quote:'not in SMS'}]]){
  const response=await handleRequest(request(),env(),{
   verifyToken:verified,
   fetchFn:async()=>({ok:true,json:async()=>({choices:[{
    message:{content:JSON.stringify({transactions:rows})}}]})}),
  });
  assert.equal(response.status,422);
 }
 const failed=await handleRequest(request(),env(),{
  verifyToken:verified,fetchFn:async()=>({ok:false,status:402})});
 assert.equal(failed.status,502);
});
test('M427 genuine RS256 App Check and forged project/app/expiry rejected',
 async()=>{
  const pair=await webcrypto.subtle.generateKey({
   name:'RSASSA-PKCS1-v1_5',modulusLength:2048,
   publicExponent:new Uint8Array([1,0,1]),hash:'SHA-256'},
   true,['sign','verify']);
  const pub=await webcrypto.subtle.exportKey('jwk',pair.publicKey);
  pub.kid='test-rsa-key';pub.alg='RS256';
  const project='1234567890';
  const app='1:1234567890:android:aabbccddeeff';
  const now=Math.floor(Date.now()/1000);
  const claims={iss:'https://firebaseappcheck.googleapis.com/'+project,
   aud:['projects/'+project],sub:app,iat:now-10,exp:now+600};
  const header={alg:'RS256',typ:'JWT',kid:'test-rsa-key'};
  const encode=v=>Buffer.from(JSON.stringify(v)).toString('base64url');
  async function jwt(payload){
   const body=encode(header)+'.'+encode(payload);
   const sig=Buffer.from(await webcrypto.subtle.sign('RSASSA-PKCS1-v1_5',
    pair.privateKey,new TextEncoder().encode(body))).toString('base64url');
   return body+'.'+sig;
  }
  const fakeFetch=async()=>({ok:true,headers:{get:()=> 'max-age=300'},
   json:async()=>({keys:[pub]})});
  const valid=await jwt(claims);
  assert.equal(await verifyAppCheckToken(valid,project,app,
   fakeFetch,webcrypto.subtle),app);
  for(const broken of [{...claims,aud:['projects/999999']},
   {...claims,sub:'1:1234567890:android:someoneelse'},
   {...claims,exp:now-5},
   {...claims,iss:'https://malicious.example'}]){
   await assert.rejects(verifyAppCheckToken(await jwt(broken),
    project,app,fakeFetch,webcrypto.subtle));
  }
  const forged=valid.slice(0,-1)+(valid.endsWith('A')?'B':'A');
  await assert.rejects(verifyAppCheckToken(forged,project,app,
   fakeFetch,webcrypto.subtle));
 });
