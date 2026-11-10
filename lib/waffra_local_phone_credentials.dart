import 'dart:convert';
import 'dart:isolate';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:crypto/crypto.dart' as legacy_crypto;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

/// M426: Local-only Saudi-phone/password verifier.
/// No SMS, Firebase phone identity, network service or subscription.
/// A phone number is a local login name, NOT verified phone ownership.
/// Result of checking whether the saved local verifier belongs to the
/// displayed account. No password, raw hash or phone is exposed to the UI.
enum WaffraLocalCredentialProbe { ready, missing, malformed, differentPhone }

/// Opaque, one-attempt-only in-memory snapshot of the OS verifier.
/// Its content is never logged, persisted, or exposed to widgets. A login
/// uses it for both the integrity probe and password challenge, avoiding a
/// second serialized Android keystore read for the same record.
class WaffraPhoneVerifierInspection {
 const WaffraPhoneVerifierInspection._(this._saved);
 final String? _saved;
}

abstract final class WaffraLocalPhoneCredentials {
 static const _store=FlutterSecureStorage();
 static const _nativeKdf=MethodChannel('waffra/password_kdf');
 // M546: older Android builds can retain a credential in Jetpack encrypted
 // preferences while the default OS-protected backend has no matching key.
 // Read ONLY when the primary is genuinely absent, never on corruption/errors.
 // Existing passwords and all encrypted finance data stay untouched.
 static const _alternateStore=FlutterSecureStorage(
  aOptions:AndroidOptions(encryptedSharedPreferences:true));
 static const _key='waffra_device_phone_credentials_v2';
 static const _iterations=600000;
 static Future<String?> _readVerifier()async{
  final primary=await _store.read(key:_key);
  if(primary!=null)return primary; // Do NOT mask damaged or foreign records.
  return _alternateStore.read(key:_key); // No new enrollment, copy or delete.
 }
 /// Called only after a login button tap; never cached across sign-in attempts.
 static Future<WaffraPhoneVerifierInspection> readForSignIn()async{
  final saved=await _readVerifier();
  return WaffraPhoneVerifierInspection._(saved);
 }
 static const _recoveryKey='waffra_phone_missing_verifier_signout_recovery_v1';

 /// One-time handoff for accounts signed in on an older APK which never
 /// persisted a secure password verifier. ONLY OS-protected storage holds it.
 /// This grant cannot authenticate alone: next login requires the same
 /// registered phone and a fresh biometric challenge before password setup.
 static bool _recoveryMatches(String? saved,String phone){
  if(!validPhone(phone)||saved==null)return false;
  try{
   final obj=jsonDecode(saved);
   if(obj is! Map<String,dynamic>||obj['version']!=1||
      obj['phoneHash'] is! String||obj['nonce'] is! String)return false;
   final nonce=base64Decode(obj['nonce'] as String);
   if(nonce.length!=32)return false;
   final expected=legacy_crypto.sha256.convert(utf8.encode(phone)).toString();
   return _equal(utf8.encode(expected),
      utf8.encode(obj['phoneHash'] as String));
  }catch(_){return false;}
 }

 static Future<bool> hasSignOutRecoveryGrant(String phone)async =>
  _recoveryMatches(await _store.read(key:_recoveryKey),phone);

 /// Called silently after Yes on sign-out, never a password or biometric
 /// dialog. Read-back failure refuses sign-out instead of stranding finances.
 static Future<bool> stageSignOutRecoveryGrant(String phone)async{
  if(!validPhone(phone)||
     await probeForPhone(phone)!=WaffraLocalCredentialProbe.missing){
   return false;
  }
  final previous=await _store.read(key:_recoveryKey);
  if(previous!=null)return _recoveryMatches(previous,phone);
  final nonce=List<int>.generate(32,(_)=>Random.secure().nextInt(256));
  final record=jsonEncode(<String,Object?>{
   'version':1,
   'phoneHash':legacy_crypto.sha256.convert(utf8.encode(phone)).toString(),
   'nonce':base64Encode(nonce),
  });
  await _store.write(key:_recoveryKey,value:record);
  return await _store.read(key:_recoveryKey)==record&&
    await probeForPhone(phone)==WaffraLocalCredentialProbe.missing;
 }

 /// Caller must FIRST validate registered phone and successfully complete
 /// fresh OS biometrics. Never called from sign-out or as an implicit reset.
 static Future<bool> finishSignInRecoveryAfterBiometric({
  required String phone,required String password,
 })async{
  if(!validPhone(phone)||!validPassword(password)||
     await probeForPhone(phone)!=WaffraLocalCredentialProbe.missing||
     !await hasSignOutRecoveryGrant(phone))return false;
  await registerOrResume(phone:phone,password:password);
  if(await probeForPhone(phone)!=WaffraLocalCredentialProbe.ready||
     !await verify(phone:phone,password:password))return false;
  await _store.delete(key:_recoveryKey);
  return true;
 }
 static bool validPhone(String phone)=>RegExp(r'^05[0-9]{8}$').hasMatch(phone);
 static bool validPassword(String pass)=>utf8.encode(pass).length>=8&&
   utf8.encode(pass).length<=128&&!pass.contains('\u0000');

 // M635: prefer Android's native PBKDF2-HMAC-SHA256 provider on a
 // dedicated Java worker. It preserves the exact persisted 600000-round,
 // 256-bit verifier format; older APKs and other platforms still verify.
 // Never cache passwords, log secrets or perform KDF on the UI thread.
 static Future<List<int>> _derive(String password,List<int> salt)async{
  if(Platform.isAndroid){
   try{
    final derived=await _nativeKdf.invokeMethod<Uint8List>(
     'derivePbkdf2Sha256',<String,Object>{
      'password':password,
      'salt':Uint8List.fromList(salt),
     });
    if(derived!=null&&derived.length==32)return derived;
   }on PlatformException{
    // The existing secure Dart isolate remains a full-strength fallback.
   }on MissingPluginException{
    // Allows upgrades from an older native Android shell.
   }
  }
  return Isolate.run<List<int>>(
   () => _deriveInBackground(password,salt),
   debugName:'waffra-pbkdf2-verifier');
 }

 static Future<List<int>> _deriveInBackground(String password,List<int> salt)async{
  final key=await Pbkdf2(macAlgorithm:Hmac.sha256(),
   iterations:_iterations,bits:256).deriveKey(
    secretKey:SecretKey(utf8.encode(password)),nonce:salt);
  return key.extractBytes();
 }
 static bool _equal(List<int> a,List<int> b){
  var d=a.length^b.length;
  for(var i=0;i<a.length||i<b.length;i++){
   d|=(i<a.length?a[i]:0)^(i<b.length?b[i]:0);
  }
  return d==0;
 }
 static Future<Map<String,Object?>> deriveRecord({
  required String phone,required String password,List<int>? testSalt,
 }) async {
  if(!validPhone(phone)||!validPassword(password)){
   throw StateError('invalid_local_credentials');
  }
  final salt=testSalt??List<int>.generate(32,(_)=>Random.secure().nextInt(256));
  if(salt.length!=32)throw StateError('invalid_salt');
  final hash=await _derive(password,salt);
  return <String,Object?>{
   'version':2,'phoneHash':legacy_crypto.sha256.convert(utf8.encode(phone)).toString(),
   'salt':base64Encode(salt),'hash':base64Encode(hash),
   'iterations':_iterations,
  };
 }
 static Future<bool> verifyRecord(Map<String,dynamic> item,{
  required String phone,required String password,
 }) async {
  if(!validPhone(phone)||!validPassword(password)||
     item['version']!=2||item['iterations']!=_iterations||
     item['phoneHash'] is! String||item['salt'] is! String||
     item['hash'] is! String)return false;
  try{
   final phoneHash=legacy_crypto.sha256.convert(utf8.encode(phone)).toString();
   if(!_equal(utf8.encode(phoneHash),utf8.encode(item['phoneHash'] as String))){
    return false;
   }
   final salt=base64Decode(item['salt'] as String);
   final expected=base64Decode(item['hash'] as String);
   if(salt.length!=32||expected.length!=32)return false;
   return _equal(await _derive(password,salt),expected);
  }catch(_){return false;}
 }
 /// A secure verifier may remain valid after an older profile was edited.
 /// The existence check never returns the phone, password or verifier bytes.
 static Future<bool> hasRegisteredCredentials() async =>
   (await _readVerifier())!=null;

 /// Check that sign-out will not strand a phone account with a missing,
 /// invalid or unrelated local verifier. This only checks verifier integrity:
 /// actual sign-in still requires matching the full password-derived key.
 static WaffraLocalCredentialProbe inspectStoredRecord(
   String? saved,{required String phone}) {
  if(saved==null)return WaffraLocalCredentialProbe.missing;
  try{
   final obj=jsonDecode(saved);
   if(obj is! Map<String,dynamic>||obj['version']!=2||
      obj['iterations']!=_iterations||
      obj['phoneHash'] is! String||
      obj['salt'] is! String||obj['hash'] is! String){
    return WaffraLocalCredentialProbe.malformed;
   }
   final salt=base64Decode(obj['salt'] as String);
   final hash=base64Decode(obj['hash'] as String);
   if(salt.length!=32||hash.length!=32){
    return WaffraLocalCredentialProbe.malformed;
   }
   if(!validPhone(phone))return WaffraLocalCredentialProbe.differentPhone;
   final phoneHash=legacy_crypto.sha256.convert(utf8.encode(phone)).toString();
   return _equal(utf8.encode(phoneHash),
     utf8.encode(obj['phoneHash'] as String))?
     WaffraLocalCredentialProbe.ready:
     WaffraLocalCredentialProbe.differentPhone;
  }catch(_){return WaffraLocalCredentialProbe.malformed;}
 }
 static Future<WaffraLocalCredentialProbe> probeForPhone(String phone,{
  WaffraPhoneVerifierInspection? inspection,
 }) async => inspection==null?
   inspectStoredRecord(await _readVerifier(),phone:phone):
   inspectStoredRecord(inspection._saved,phone:phone);

 static Future<void> register({required String phone,
  required String password})async{
  final saved=await _readVerifier();
  if(saved!=null){
   // Never overwrite a user's password without verifying existing credentials.
   // Reset/login recovery requires a dedicated owner-approved workflow.
   throw StateError('local_credentials_already_exist');
  }
  final payload=await deriveRecord(phone:phone,password:password);
  await _store.write(key:_key,value:jsonEncode(payload));
 }
 /// Resume an interrupted registration only after proving that the EXACT
 /// same phone and password own the existing OS-protected verifier.
 /// Never rotate a verifier, create a second identity, or erase secure data.
 static Future<void> registerOrResume({
  required String phone,required String password,
 })async{
  if(!validPhone(phone)||!validPassword(password)){
   throw StateError('invalid_local_credentials');
  }
  final saved=await _readVerifier();
  if(saved==null){
   // Fresh enrollment needs ONE full-strength 600000-round derivation, not
   // a redundant second PBKDF2 just to prove the write survived storage.
   // Verify the complete saved salt/hash/phone/iteration record byte-for-byte.
   // Interrupted registrations with an existing verifier still require the
   // original phone+password cryptographic challenge below.
   final record=await deriveRecord(phone:phone,password:password);
   final encoded=jsonEncode(record);
   // Recheck after the expensive derivation; an overlapping enrollment must
   // never silently rotate a verifier that appeared while the worker ran.
   if(await _readVerifier()!=null){
    throw StateError('local_credentials_already_exist');
   }
   await _store.write(key:_key,value:encoded);
   final persisted=await _store.read(key:_key);
   if(persisted==null||
      !_equal(utf8.encode(persisted),utf8.encode(encoded))){
    throw StateError('local_credential_write_unverified');
   }
   return;
  }
  if(await canResumeRecord(saved,phone:phone,password:password))return;
  throw StateError('local_credentials_already_exist');
 }
 /// Decode and challenge a pre-existing verifier without ever storing the
 /// phone or password or accepting malformed records as registration consent.
 static Future<bool> canResumeRecord(String saved,{
  required String phone,required String password,
 })async{
  try{
   final record=jsonDecode(saved);
   return record is Map<String,dynamic> &&
     await verifyRecord(record,phone:phone,password:password);
  }catch(_){return false;}
 }
 static Future<bool> verify({
  required String phone,required String password,
  String? oldSalt,String? oldHash,
  WaffraPhoneVerifierInspection? inspection,
 })async{
  if(!validPhone(phone)||!validPassword(password))return false;
  // The snapshot is scoped to this login attempt. Its immutable verifier is
  // still checked against the entered phone before PBKDF2 can authenticate.
  final saved=inspection==null?await _readVerifier():inspection._saved;
  if(saved!=null){
   final obj=jsonDecode(saved);
   return obj is Map<String,dynamic> &&
     await verifyRecord(obj,phone:phone,password:password);
  }
  // Upgrade legacy salted SHA-256 only after a successful old-password
  // login. Never interpret a bad password as permission to reset a profile.
  if(oldSalt==null||oldHash==null)return false;
  final supplied=legacy_crypto.sha256.convert(utf8.encode('$oldSalt:$password')).toString();
  if(!_equal(utf8.encode(supplied),utf8.encode(oldHash)))return false;
  await register(phone:phone,password:password);
  return true;
 }
}
