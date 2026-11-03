'use strict';

// M425: Server-only credentials and in-place Firebase UID identity mapping.
// No password hash or Firebase service account secret ever reaches Flutter.
// No function here can read/write the customer's finance ledger or backups.
const crypto = require('node:crypto');
const {promisify} = require('node:util');
const scrypt = promisify(crypto.scrypt);
const PARAMS = Object.freeze({N: 1 << 16, r: 8, p: 2, maxmem: 256 * 1024 * 1024});
const WINDOW = 15 * 60 * 1000;
const MAX_ATTEMPTS = 5;
const TOKEN_AGE_SECONDS = 300;
const GENERIC_ERROR = 'INVALID_CREDENTIALS';

function normalizeSaudiPhone(value) {
  if (typeof value !== 'string') throw Error('INVALID_PHONE');
  if (/^05[0-9]{8}$/.test(value)) return '+966' + value.slice(1);
  if (/^\+9665[0-9]{8}$/.test(value)) return value;
  throw Error('INVALID_PHONE');
}
function validatePassword(value) {
  if (typeof value !== 'string') throw Error('INVALID_PASSWORD');
  const bytes = Buffer.byteLength(value,'utf8');
  if (bytes < 8 || bytes > 128 || value.includes('\0')) {
    throw Error('INVALID_PASSWORD');
  }
  return value;
}
function requirePepper(pepper) {
  if (typeof pepper !== 'string' || Buffer.byteLength(pepper) < 32)
    throw Error('PHONE_AUTH_NOT_CONFIGURED');
  return pepper;
}
function lookupId(phone, pepper) {
  return crypto.createHmac('sha256', requirePepper(pepper))
    .update('waffra-phone-lookup-v1|' + normalizeSaudiPhone(phone))
    .digest('hex');
}
function authContext(request, authUser, now = Math.floor(Date.now() / 1000)) {
  const uid = request?.auth?.uid;
  const claims = request?.auth?.token;
  if (typeof uid !== 'string' || !uid || uid.length > 128 ||
      uid.includes('/') || authUser?.uid !== uid || authUser.disabled) {
    throw Error('UNAUTHENTICATED');
  }
  if (!request.app?.appId) throw Error('APP_CHECK_REQUIRED');
  const proof = Number(claims?.auth_time);
  if (!Number.isInteger(proof) || proof > now ||
      now - proof > TOKEN_AGE_SECONDS) throw Error('RECENT_AUTH_REQUIRED');
  return uid;
}
function verifiedPhoneOwner(request, authUser, phone, now) {
  const uid = authContext(request, authUser, now);
  if (authUser.phoneNumber !== normalizeSaudiPhone(phone)) {
    throw Error('PHONE_NOT_VERIFIED');
  }
  // Both Firebase Auth's phone-number field and recent authenticated session
  // must be present. The client must use an actual Firebase OTP credential to
  // attach or reauthenticate phone ownership before calling enrollment/reset.
  const claimedNumber = request?.auth?.token?.phone_number;
  if (claimedNumber !== authUser.phoneNumber) throw Error('PHONE_NOT_VERIFIED');
  return uid;
}
async function hashPassword(password, pepper, salt) {
  validatePassword(password);
  requirePepper(pepper);
  const nonce = salt || crypto.randomBytes(32);
  if (!Buffer.isBuffer(nonce) || nonce.length !== 32) throw Error('BAD_SALT');
  const secret = crypto.createHmac('sha256',pepper)
    .update('waffra-pass-v1\0').update(password,'utf8').digest();
  const derived = await scrypt(secret, nonce, 64, PARAMS);
  return {version:1,algorithm:'scrypt',N:PARAMS.N,r:PARAMS.r,p:PARAMS.p,
    salt:nonce.toString('base64'),hash:derived.toString('base64')};
}
async function checkPassword(password, pepper, record) {
  validatePassword(password);
  requirePepper(pepper);
  const valid = record && record.version === 1 &&
    record.algorithm === 'scrypt' && record.N === PARAMS.N &&
    record.r === PARAMS.r && record.p === PARAMS.p &&
    typeof record.salt === 'string' && typeof record.hash === 'string';
  // Intentionally perform an equally expensive derivation for missing or
  // corrupt accounts to make user enumeration by response time less useful.
  const nonce = valid ? Buffer.from(record.salt,'base64') : Buffer.alloc(32);
  if (nonce.length !== 32) return false;
  const actual = await hashPassword(password, pepper, nonce);
  const expected = valid ? Buffer.from(record.hash,'base64') : Buffer.alloc(64);
  if (expected.length !== 64) return false;
  return crypto.timingSafeEqual(Buffer.from(actual.hash,'base64'),expected);
}
function requireAppCheck(request) {
  if (!request?.app?.appId) throw Error('APP_CHECK_REQUIRED');
}
function safeTime(value) { return Number.isFinite(value) ? value : 0; }

// In-memory logic is testable; repository functions injected by the Firebase
// adapter MUST use a Firestore transaction for enroll and throttling.
async function enroll({request,phone,password,pepper,authAdmin,store,
  now = Math.floor(Date.now()/1000)}) {
  requireAppCheck(request);
  const e164 = normalizeSaudiPhone(phone);
  validatePassword(password);
  const user = await authAdmin.getUser(request?.auth?.uid);
  const uid = verifiedPhoneOwner(request,user,e164,now);
  const key = lookupId(e164,pepper);
  const digest = await hashPassword(password,pepper);
  const result = await store.bindPhone({key,uid,e164,
    passwordDigest:digest,at:now});
  if (result !== true) throw Error('PHONE_ALREADY_REGISTERED');
  // Existing Firebase UID is unchanged. Never touch existing finance data.
  return {enrolled:true,uid};
}
async function signIn({request,phone,password,pepper,authAdmin,store,
  nowMs=Date.now()}) {
  requireAppCheck(request);
  // Give an indistinguishable error to unknown number, wrong password, and
  // disabled account. Valid format is still mandatory (not user existence).
  const e164 = normalizeSaudiPhone(phone);
  validatePassword(password);
  const key = lookupId(e164,pepper);
  const allowed = await store.attempt({key,nowMs,windowMs:WINDOW,
    maxAttempts:MAX_ATTEMPTS});
  if (!allowed) throw Error('TOO_MANY_ATTEMPTS');
  const owner = await store.phoneOwner(key);
  const stored = owner?.uid && await store.passwordRecord(owner.uid);
  const okay = await checkPassword(password,pepper,stored?.digest);
  if (!okay || !owner?.uid || stored?.phoneKey !== key) {
    throw Error(GENERIC_ERROR);
  }
  let user;
  try { user = await authAdmin.getUser(owner.uid); } catch (_) {
    throw Error(GENERIC_ERROR);
  }
  if (user.disabled || user.phoneNumber !== e164) {
    throw Error(GENERIC_ERROR);
  }
  // Signed one-hour Firebase custom token. Client exchanges it for a Firebase
  // identity session; existing user UID and ledger namespace stay unchanged.
  const token = await authAdmin.createCustomToken(owner.uid,{waffraPhone:true});
  return {customToken:token};
}
async function resetPassword({request,phone,newPassword,pepper,authAdmin,store,
  now=Math.floor(Date.now()/1000)}) {
  requireAppCheck(request);
  const e164 = normalizeSaudiPhone(phone);
  validatePassword(newPassword);
  const user = await authAdmin.getUser(request?.auth?.uid);
  const uid = verifiedPhoneOwner(request,user,e164,now);
  const key = lookupId(e164,pepper);
  const digest = await hashPassword(newPassword,pepper);
  const changed = await store.resetPassword({uid,key,e164,digest,at:now});
  if (!changed) throw Error('PHONE_NOT_LINKED');
  // Revoke all old Firebase refresh sessions on reset.
  await authAdmin.revokeRefreshTokens(uid);
  return {reset:true};
}
module.exports={normalizeSaudiPhone,validatePassword,requirePepper,lookupId,
  authContext,verifiedPhoneOwner,hashPassword,checkPassword,
  enroll,signIn,resetPassword,PARAMS,WINDOW,MAX_ATTEMPTS};
