// Verify genuine Firebase App Check RS256 attestation at Cloudflare's edge.
const jwksUrl='https://firebaseappcheck.googleapis.com/v1/jwks';
let cached,expire=0;
function decode(x){
 if(typeof x!=='string'||x.length>15000||!/^[A-Za-z0-9_-]+$/.test(x))
  throw Error('bad_base64');
 const v=atob(x.replace(/-/g,'+').replace(/_/g,'/')
  .padEnd(Math.ceil(x.length/4)*4,'='));
 return Uint8Array.from(v,c=>c.charCodeAt(0));
}
function part(x){return JSON.parse(new TextDecoder().decode(decode(x)));}
async function keys(fetchFn){
 if(cached&&Date.now()<expire)return cached;
 const response=await fetchFn(jwksUrl,{signal:AbortSignal.timeout(4000)});
 if(!response?.ok)throw Error('jwks_fetch_failed');
 const data=await response.json();
 if(!Array.isArray(data?.keys)||data.keys.length>20)throw Error('invalid_jwks');
 cached=data.keys;
 const ttl=Number(response.headers?.get('cache-control')
  ?.match(/max-age=(\d+)/)?.[1]||300);
 expire=Date.now()+Math.max(30,Math.min(3600,ttl))*1000;
 return cached;
}
export async function verifyAppCheckToken(token,project,appId,
 fetchFn=fetch,subtle=crypto.subtle){
 if(typeof project!=='string'||!/^\d{6,20}$/.test(project)||
  typeof appId!=='string'||!/^\d+:\d+:android:[A-Za-z0-9]+$/.test(appId)||
  typeof token!=='string'||token.length>10000)throw Error('invalid_config');
 const sections=token.split('.');
 if(sections.length!==3)throw Error('invalid_jwt');
 const head=part(sections[0]),payload=part(sections[1]);
 const now=Math.floor(Date.now()/1000);
 if(head?.alg!=='RS256'||head?.typ!=='JWT'||
  typeof head.kid!=='string'||head.kid.length>150||
  payload?.iss!=='https://firebaseappcheck.googleapis.com/'+project||
  !Array.isArray(payload.aud)||!payload.aud.includes('projects/'+project)||
  payload.sub!==appId||!Number.isInteger(payload.exp)||payload.exp<=now||
  !Number.isInteger(payload.iat)||payload.iat>now||
  payload.exp-now>86400)throw Error('invalid_claims');
 const jwks=await keys(fetchFn);
 const jwk=jwks.find(k=>k.kid===head.kid&&k.kty==='RSA'&&
  (!k.alg||k.alg==='RS256')&&typeof k.n==='string'&&typeof k.e==='string');
 if(!jwk)throw Error('unknown_key');
 const publicKey=await subtle.importKey('jwk',jwk,
  {name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'},false,['verify']);
 const valid=await subtle.verify('RSASSA-PKCS1-v1_5',publicKey,
  decode(sections[2]),new TextEncoder().encode(sections[0]+'.'+sections[1]));
 if(!valid)throw Error('invalid_signature');
 return payload.sub;
}
