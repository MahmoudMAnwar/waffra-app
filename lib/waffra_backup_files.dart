import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'waffra_secure_backup.dart';

/// User-controlled Android Storage Access Framework backup file handoff.
/// Encrypted data is never put onto the system clipboard during export.
class WaffraBackupFiles {
 const WaffraBackupFiles._();
 static const MethodChannel channel=MethodChannel('waffra/backup_files');
 static const int maxArchiveBytes=8*1024*1024;

 static bool get supported => Platform.isAndroid;

 static String suggestedName([DateTime? at]) {
  final now=(at??DateTime.now()).toLocal();
  String two(int value)=>value.toString().padLeft(2,'0');
  final stamp=now.year.toString().padLeft(4,'0')+'-'+two(now.month)
   +'-'+two(now.day)+'_'+two(now.hour)+two(now.minute)+two(now.second);
  return 'Waffra_Backup_'+stamp+'.waffra';
 }

 /// Refuse accidental exports of raw financial JSON, also checked natively.
 static bool isEncryptedArchive(String payload) {
  return WaffraSecureBackup.hasValidEncryptedHeader(payload);
 }

 /// False means the user cancelled document selection, not a successful save.
 static Future<bool> saveEncryptedArchive(String payload,{String? name}) async {
  if(!supported)throw UnsupportedError(
   'Encrypted file export currently requires Android');
  if(!isEncryptedArchive(payload)){
   throw const FormatException('Only encrypted Waffra archives can be saved');
  }
  if(utf8.encode(payload).length>maxArchiveBytes){
   throw const FormatException('Encrypted backup exceeds the 8 MB limit');
  }
  return await channel.invokeMethod<bool>('saveEncryptedFile',{
   'fileName':name??suggestedName(),
   'encryptedPayload':payload,
  })??false;
 }

 /// Null means user cancelled picker. Accept both encrypted .waffra and
 /// existing JSON backup documents: the existing decryptor authenticates.
 static Future<String?> openArchive() async {
  if(!supported)throw UnsupportedError(
   'Encrypted file import currently requires Android');
  final raw=await channel.invokeMethod<String>('openEncryptedFile');
  if(raw==null)return null;
  if(raw.isEmpty||utf8.encode(raw).length>maxArchiveBytes){
   throw const FormatException('Invalid or oversized backup file');
  }
  if(!isEncryptedArchive(raw)){
   throw const FormatException('Selected file is not a valid encrypted Waffra backup');
  }
  return raw;
 }
}
