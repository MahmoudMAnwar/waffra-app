import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart' as legacy_crypto;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// M426: Local-only Saudi-phone/password verifier.
/// No SMS, Firebase phone identity, network service or subscription.
/// A phone number is a local login name, NOT verified phone ownership.
abstract final class WaffraLocalPhoneCredentials {
 static const _store=FlutterSecureStorage();
 static const _key='waffra_device_phone_credentials_v2';
 static const _iterations=600000;
 static bool validPhone(String phone)=>RegExp(r'^05[0-9]{8}$').hasMatch(phone);
 static bool validPassword(String pass)=>utf8.encode(pass).length>=8&&
   utf8.encode(pass).length<=128&&!pass.contains('\u0000');

 static Future<List<int>> _derive(String password,List<int> salt) async {
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
 static Future<void> register({required String phone,
  required String password})async{
  final saved=await _store.read(key:_key);
  if(saved!=null){
   // Never overwrite a user's password without verifying existing credentials.
   // Reset/login recovery requires a dedicated owner-approved workflow.
   throw StateError('local_credentials_already_exist');
  }
  final payload=await deriveRecord(phone:phone,password:password);
  await _store.write(key:_key,value:jsonEncode(payload));
 }
 static Future<bool> verify({
  required String phone,required String password,
  String? oldSalt,String? oldHash,
 })async{
  if(!validPhone(phone)||!validPassword(password))return false;
  final saved=await _store.read(key:_key);
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
