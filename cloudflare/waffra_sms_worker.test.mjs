import test from 'node:test';
import assert from 'node:assert/strict';
import {webcrypto} from 'node:crypto';
import {handleRequest, verifyFirebaseIdToken} from './waffra_sms_worker.mjs';

const endpoint = 'https://waffra-sms-staging.example.workers.dev/analyze';
const bank = 'SAR 75.00 debited at TEST STORE';
const suggestion = {
  direction:'expense',amount:'75.00',currency:'SAR',
  description:'TEST STORE',source_quote:bank,
};
const env = () => ({
  OPENROUTER_API_KEY:'fake-secret-do-not-send',
  FIREBASE_PROJECT_ID:'waffra-demo',
  SMS_RATE_LIMITER:{limit:async()=>({success:true})},
});
const request = (body, token = 'fake.signed.token') =>
  new Request(endpoint,{
    method:'POST',
    headers:{authorization:'Bearer '+token,'content-type':'application/json'},
    body:JSON.stringify(body),
  });
const validBody = {text:bank,cloudConsent:true};
const authorized = async () => 'firebase-user-123';

test('M423: configured health reports ready but never returns secrets',async()=>{
  const result=await handleRequest(new Request(endpoint.replace('/analyze','/health')),env());
  const body=await result.json();
  assert.equal(body.ready,true);
  assert.equal(JSON.stringify(body).includes('fake-secret'),false);
});
test('M423: GET analyze cannot invoke provider',async()=>{
  const result=await handleRequest(new Request(endpoint),env());
  assert.equal(result.status,405);
});
test('M423: bearer required; static staging secret rejected by default',async()=>{
  let calls=0;
  const e=env();e.WAFFRA_STAGING_TOKEN='fake-token';
  for(const req of [
    new Request(endpoint,{method:'POST'}),
    request(validBody,'fake-token'),
  ]){
    const r=await handleRequest(req,e,{verifyToken:async()=>{calls++;throw Error('INVALID');}});
    assert.equal(r.status,401);
  }
  assert.equal(calls,1);
});
test('M423: absent server rate limiter or Firebase project fails closed',async()=>{
  const e=env();delete e.SMS_RATE_LIMITER;
  assert.equal((await handleRequest(request(validBody),e)).status,503);
  const other=env();delete other.FIREBASE_PROJECT_ID;
  assert.equal((await handleRequest(request(validBody),other)).status,503);
});
test('M423: missing explicit opt-in never calls provider',async()=>{
  let providerCalls=0;
  for(const input of [
    {text:bank}, {text:bank,cloudConsent:false},
    {text:'OTP 1234 for a SAR 75.00 purchase',cloudConsent:true},
    {text:'SAR 75.00 debited. Account SA0380000000608010167519',cloudConsent:true},
  ]){
    const res=await handleRequest(request(input),env(),{
      verifyToken:authorized,
      fetchFn:async()=>{providerCalls++;throw Error('provider_not_called');},
    });
    assert.equal(res.status,422);
  }
  assert.equal(providerCalls,0);
});
test('M423: rate limit blocks before invoking OpenRouter',async()=>{
  const e=env();e.SMS_RATE_LIMITER={limit:async()=>({success:false})};
  let providerCalls=0;
  const result=await handleRequest(request(validBody),e,{
    verifyToken:authorized,
    fetchFn:async()=>{providerCalls++;throw Error('should not call');},
  });
  assert.equal(result.status,429);
  assert.equal(providerCalls,0);
});
test('M423: test expense uses server secret and remains review-only',async()=>{
  let calls=0;
  const res=await handleRequest(request(validBody),env(),{
    verifyToken:authorized,
    fetchFn:async(url,config)=>{
      calls++;
      assert.equal(url,'https://openrouter.ai/api/v1/chat/completions');
      assert.equal(config.headers.authorization,'Bearer fake-secret-do-not-send');
      const body=JSON.parse(config.body);
      assert.equal(body.model,'openrouter/free');
      assert.equal(body.provider.zdr,true);
      assert.equal(body.provider.data_collection,'deny');
      assert.equal(body.messages[1].content,bank);
      return {ok:true,json:async()=>({
        choices:[{message:{content:JSON.stringify({transactions:[suggestion]})}}]
      })};
    },
  });
  const body=await res.json();
  assert.equal(res.status,200);
  assert.equal(calls,1);
  assert.equal(body.unverified,true);
  assert.equal(body.review_required,true);
  assert.equal(body.transactions[0].amount,'75.00');
  assert.equal(JSON.stringify(body).includes('fake-secret'),false);
});
test('M423: invented quote, double-counting and provider failure rejected',async()=>{
  for(const candidate of [
    {transactions:[{...suggestion,source_quote:'not present in SMS'}]},
    {transactions:[suggestion,suggestion]},
  ]){
    const res=await handleRequest(request(validBody),env(),{
      verifyToken:authorized,
      fetchFn:async()=>({ok:true,json:async()=>({
        choices:[{message:{content:JSON.stringify(candidate)}}]})}),
    });
    assert.equal(res.status,422);
  }
  const res=await handleRequest(request(validBody),env(),{
    verifyToken:authorized,
    fetchFn:async()=>({ok:false,status:429}),
  });
  assert.equal(res.status,502);
});
test('M423: verify genuine Firebase RS256 signature and reject forgery',async()=>{
  const pair=await webcrypto.subtle.generateKey(
    {name:'RSASSA-PKCS1-v1_5',modulusLength:2048,
      publicExponent:new Uint8Array([1,0,1]),hash:'SHA-256'},
    true,['sign','verify']);
  const spki=Buffer.from(await webcrypto.subtle.exportKey('spki',pair.publicKey));
  const pem='-----BEGIN PUBLIC KEY-----\n'+
    spki.toString('base64').match(/.{1,64}/g).join('\n')+
    '\n-----END PUBLIC KEY-----';
  const b64 = input=>Buffer.from(JSON.stringify(input)).toString('base64url');
  const now=Math.floor(Date.now()/1000);
  const header=b64({alg:'RS256',kid:'unit-test-kid'});
  const body=b64({sub:'firebase-user-123',aud:'waffra-demo',
    iss:'https://securetoken.google.com/waffra-demo',
    iat:now-10,auth_time:now-10,exp:now+300,
    firebase:{sign_in_provider:'phone'}});
  const signing=header+'.'+body;
  const signature=Buffer.from(await webcrypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',pair.privateKey,new TextEncoder().encode(signing)))
    .toString('base64url');
  const jwt=signing+'.'+signature;
  const fakeFetch=async()=>({ok:true,headers:{get:()=> 'public, max-age=60'},
    json:async()=>({'unit-test-kid':pem})});
  assert.equal(await verifyFirebaseIdToken(jwt,'waffra-demo',
    fakeFetch,webcrypto.subtle),'firebase-user-123');
  await assert.rejects(verifyFirebaseIdToken(jwt,'other-demo',
    fakeFetch,webcrypto.subtle));
  await assert.rejects(verifyFirebaseIdToken(jwt.slice(0,-2)+'AA',
    fakeFetch,webcrypto.subtle));
});
