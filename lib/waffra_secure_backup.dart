import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

/// Password-derived AES-256-GCM backups. Passwords never leave this method
/// and are never stored in local preferences or included in export metadata.
class WaffraSecureBackup {
 const WaffraSecureBackup._();
 static final _cipher=AesGcm.with256bits();
 static final _kdf=Pbkdf2(macAlgorithm:Hmac.sha256(),iterations:120000,bits:256);

 static List<int> _random(int length){
  final secure=Random.secure();
  return List<int>.generate(length,(_)=>secure.nextInt(256));
 }

 /// New export passwords are deliberately fixed-length and ASCII-only.
 /// Legacy archives retain their original decryption requirements so their
 /// owners can restore safely instead of being locked out of old backups.
 static bool isValidNewPassword(String password) =>
  RegExp(r'^(?=.*[A-Za-z])(?=.*[0-9])[A-Za-z0-9]{8}
  final salt=_random(16),nonce=_random(12);
  final key=await _kdf.deriveKey(secretKey:SecretKey(utf8.encode(password)),nonce:salt);
  final box=await _cipher.encrypt(utf8.encode(plaintext),secretKey:key,nonce:nonce);
  return jsonEncode({
   'format':'waffra-secure-backup','version':1,'kdf':'pbkdf2-sha256',
   'iterations':120000,'cipher':'aes-256-gcm',
   'salt':base64Encode(salt),'nonce':base64Encode(box.nonce),
   'data':base64Encode(box.cipherText),'mac':base64Encode(box.mac.bytes),
  });
 }

 static Future<String> decrypt(String payload,String password) async {
  final decoded=jsonDecode(payload);
  if(decoded is! Map)throw const FormatException('Invalid backup');
  // Old unencrypted backups remain importable for backwards compatibility.
  if(decoded['format']=='waffra-backup')return payload;
  if(decoded['format']!='waffra-secure-backup'||decoded['version']!=1||
    decoded['iterations']!=120000||decoded['cipher']!='aes-256-gcm'){
   throw const FormatException('Unsupported encrypted backup');
  }
  if(password.isEmpty)throw const FormatException('Password required');
  final salt=base64Decode(decoded['salt'] as String);
  final nonce=base64Decode(decoded['nonce'] as String);
  final data=base64Decode(decoded['data'] as String);
  final mac=Mac(base64Decode(decoded['mac'] as String));
  if(salt.length!=16||nonce.length!=12||mac.bytes.length!=16){
   throw const FormatException('Corrupted encrypted backup');
  }
  final key=await _kdf.deriveKey(secretKey:SecretKey(utf8.encode(password)),nonce:salt);
  final bytes=await _cipher.decrypt(SecretBox(data,nonce:nonce,mac:mac),secretKey:key);
  return utf8.decode(bytes);
 }
}
).hasMatch(password);

 static Future<String> encrypt(String plaintext,String password) async {
  if(!isValidNewPassword(password)){
   throw const FormatException(
    'New backup password must be exactly 8 alphanumeric characters with a letter and digit',
   );
  }
  final salt=_random(16),nonce=_random(12);
  final key=await _kdf.deriveKey(secretKey:SecretKey(utf8.encode(password)),nonce:salt);
  final box=await _cipher.encrypt(utf8.encode(plaintext),secretKey:key,nonce:nonce);
  return jsonEncode({
   'format':'waffra-secure-backup','version':1,'kdf':'pbkdf2-sha256',
   'iterations':120000,'cipher':'aes-256-gcm',
   'salt':base64Encode(salt),'nonce':base64Encode(box.nonce),
   'data':base64Encode(box.cipherText),'mac':base64Encode(box.mac.bytes),
  });
 }

 static Future<String> decrypt(String payload,String password) async {
  final decoded=jsonDecode(payload);
  if(decoded is! Map)throw const FormatException('Invalid backup');
  // Old unencrypted backups remain importable for backwards compatibility.
  if(decoded['format']=='waffra-backup')return payload;
  if(decoded['format']!='waffra-secure-backup'||decoded['version']!=1||
    decoded['iterations']!=120000||decoded['cipher']!='aes-256-gcm'){
   throw const FormatException('Unsupported encrypted backup');
  }
  if(password.isEmpty)throw const FormatException('Password required');
  final salt=base64Decode(decoded['salt'] as String);
  final nonce=base64Decode(decoded['nonce'] as String);
  final data=base64Decode(decoded['data'] as String);
  final mac=Mac(base64Decode(decoded['mac'] as String));
  if(salt.length!=16||nonce.length!=12||mac.bytes.length!=16){
   throw const FormatException('Corrupted encrypted backup');
  }
  final key=await _kdf.deriveKey(secretKey:SecretKey(utf8.encode(password)),nonce:salt);
  final bytes=await _cipher.decrypt(SecretBox(data,nonce:nonce,mac:mac),secretKey:key);
  return utf8.decode(bytes);
 }
}
