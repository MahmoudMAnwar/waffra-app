import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

/// Password-authenticated portable backups. V2 is Argon2id + AES-256-GCM;
/// restore continues to support legacy V1 PBKDF2 archives. No password,
/// financial plaintext, or derived encryption key is stored in the export.
class WaffraSecureBackup {
 const WaffraSecureBackup._();
 static final _cipher=AesGcm.with256bits();
 static final _legacyKdf=Pbkdf2(macAlgorithm:Hmac.sha256(),iterations:120000,bits:256);
 // OWASP Argon2id: 19 MiB, two passes, one lane.
 static const int _argonMemory=19456, _argonIterations=2, _argonParallelism=1;
 static final _v2Kdf=Argon2id(memory:_argonMemory,iterations:_argonIterations,
  parallelism:_argonParallelism,hashLength:32);

 static List<int> _random(int length){
  final secure=Random.secure();
  return List<int>.generate(length,(_)=>secure.nextInt(256));
 }

 /// No silently truncated passwords. Accept strong passphrases with symbols,
 /// non-ASCII characters and spaces; do not impose the old eight-slot rule.
 static bool isValidNewPassword(String password)=>
  password.runes.length>=12&&password.runes.length<=256;

 static Future<String> encryptUserBackup(String plaintext,String password) async {
  if(!isValidNewPassword(password)){
   throw const FormatException('Backup password must contain 12 to 256 characters');
  }
  return encrypt(plaintext,password);
 }

 /// Fresh exports only use V2. Isolate encryption in the calling UI to avoid
 /// blocking frames while the memory-hard KDF executes.
 static Future<String> encrypt(String plaintext,String password) async {
  if(!isValidNewPassword(password)){
   throw const FormatException('Backup password must contain 12 to 256 characters');
  }
  final salt=_random(16),nonce=_random(12);
  final key=await _v2Kdf.deriveKey(secretKey:SecretKey(utf8.encode(password)),nonce:salt);
  final box=await _cipher.encrypt(utf8.encode(plaintext),secretKey:key,nonce:nonce);
  return jsonEncode({
   'format':'waffra-secure-backup','version':2,'kdf':'argon2id',
   'memory':_argonMemory,'iterations':_argonIterations,'parallelism':_argonParallelism,
   'cipher':'aes-256-gcm','salt':base64Encode(salt),
   'nonce':base64Encode(box.nonce),'data':base64Encode(box.cipherText),
   'mac':base64Encode(box.mac.bytes),
  });
 }

 /// Header only: must not imply the password is correct or the archive can
 /// be restored. Authenticated decryption is always required before mutation.
 static bool hasValidEncryptedHeader(String payload){
  try{
   final data=jsonDecode(payload);
   if(data is! Map||data['format']!='waffra-secure-backup'||
      data['cipher']!='aes-256-gcm')return false;
   final version=data['version'];
   if(version==1){
    if(data['kdf']!='pbkdf2-sha256'||data['iterations']!=120000)return false;
   }else if(version==2){
    if(data['kdf']!='argon2id'||data['memory']!=_argonMemory||
     data['iterations']!=_argonIterations||
     data['parallelism']!=_argonParallelism)return false;
   }else{return false;}
   for(final k in ['salt','nonce','data','mac']){
    if(data[k] is! String)return false;
   }
   return base64Decode(data['salt'] as String).length==16&&
    base64Decode(data['nonce'] as String).length==12&&
    base64Decode(data['mac'] as String).length==16&&
    data['data'] is String;
  }catch(_){return false;}
 }

 static Future<String> decrypt(String payload,String password) async {
  final decoded=jsonDecode(payload);
  if(decoded is! Map)throw const FormatException('Invalid backup');
  // Advanced legacy text import must remain possible but NEVER exported.
  if(decoded['format']=='waffra-backup')return payload;
  if(!hasValidEncryptedHeader(payload)){
   throw const FormatException('Invalid or corrupted Waffra backup');
  }
  if(password.isEmpty)throw const FormatException('Password required');
  final salt=base64Decode(decoded['salt'] as String);
  final nonce=base64Decode(decoded['nonce'] as String);
  final data=base64Decode(decoded['data'] as String);
  final mac=Mac(base64Decode(decoded['mac'] as String));
  final version=decoded['version'];
  final key=await (version==2?_v2Kdf:_legacyKdf).deriveKey(
   secretKey:SecretKey(utf8.encode(password)),nonce:salt);
  final bytes=await _cipher.decrypt(SecretBox(data,nonce:nonce,mac:mac),secretKey:key);
  return utf8.decode(bytes);
 }
}
