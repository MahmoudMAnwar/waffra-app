import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_merchant_rules.dart';
import 'package:waffra/waffra_secure_backup.dart';
import 'package:waffra/waffra_backup_files.dart';

void main(){
 test('M153: long legacy bank SMS descriptions do not block attachment edits',(){
  final legacy=List.filled(5000,'أ').join();
  expect(waffraTransactionTitleAllowed(legacy,oldTitle:legacy),isTrue);
  expect(waffraTransactionTitleAllowed(legacy+'!',oldTitle:legacy),isFalse);
  expect(waffraTransactionTitleAllowed('شراء من تاجر معروف'),isTrue);
  expect(waffraTransactionTitleAllowed(List.filled(251,'a').join()),isFalse);
  expect(waffraTransactionNotesAllowed(List.filled(2000,'x').join()),isTrue);
  expect(waffraTransactionNotesAllowed(List.filled(2001,'x').join()),isFalse);
  final entry=MoneyEntry(id:'old1',title:legacy,category:'أخرى / مصروف غير مصنف',
   income:false,amount:10.5,date:DateTime(2026,10,20),notes:'',sourceType:'sms');
  final restored=MoneyEntry.fromJson(entry.toJson());
  expect(restored.title,legacy);
  expect(restored.sourceType,'sms');
 });

 test('M153: synthetic 30-message bulk classification matches totals and deduplicated names',(){
  final records=<String>[];
  // No real bank account numbers or personal messages enter source control.
  for(var i=0;i<11;i++){
   records.add('حوالة داخلية واردة بـSR 10\nلـ1111\nمن2222;شخص مثال '+(i%3).toString()+'\n26/10/17 12:34');
  }
  for(var i=0;i<4;i++){
   records.add('حوالة داخلية صادرة بـSR 15\nمن1111\nلـ2222;مستفيد مثال '+(i%2).toString()+'\n26/10/16 19:23');
  }
  for(var i=0;i<15;i++){
   records.add('شراء PoS\nعبر:1111;مدى\nبـSAR 20\nلـ'+(i%2==0?'SHAWARMA H':'shawerma h')+'\n15/10/26 16:09');
  }
  final text=records.join('\n');
  final messages=splitBankMessages(text);
  expect(messages.length,30);
  final parsed=messages.map(BankParser.parse).toList();
  expect(parsed.where((e)=>e.income).length,11);
  expect(parsed.where((e)=>!e.income).length,19);
  expect(parsed.fold<double>(0,(n,e)=>n+(e.amount??0)),470);
  expect(waffraMerchantKey(messages[15]),waffraMerchantKey(messages[16]));
  expect(bankSmsDate(messages.first),DateTime(2026,10,17,12,34));
  expect(bankSmsDate(messages.last),DateTime(2026,10,15,16,9));
 });

 test('M153: file validation is contents-based, not extension-based',()async{
  final ciphertext=await WaffraSecureBackup.encryptUserBackup(
   jsonEncode({'format':'waffra-backup','entries':[]}), 'Long backup password 2026!');
  expect(WaffraBackupFiles.isEncryptedArchive(ciphertext),isTrue);
  expect(WaffraBackupFiles.isEncryptedArchive('renamed.pdf.waffra'),isFalse);
  expect(WaffraBackupFiles.isEncryptedArchive(
   '{"format":"waffra-backup","entries":[]}'),isFalse);
  final tampered=Map<String,dynamic>.from(jsonDecode(ciphertext) as Map);
  tampered['nonce']='short';
  expect(WaffraBackupFiles.isEncryptedArchive(jsonEncode(tampered)),isFalse);
  expect(await WaffraSecureBackup.decrypt(ciphertext,'Long backup password 2026!'),
   contains('waffra-backup'));
  await expectLater(WaffraSecureBackup.decrypt(ciphertext,'Bad backup password 2026!'),
   throwsA(isA<Exception>()));
 });

 test('M153: new backup screen is uncluttered and preserves legacy restore',(){
  final source=File('lib/main.dart').readAsStringSync();
  final start=source.indexOf('Future<void> backupDialog()');
  final end=source.indexOf('// System credentials are never saved',start);
  final dialog=source.substring(start,end);
  expect(dialog,contains('if(mode==0)'));
  expect(dialog,contains('if(mode==1)'));
  expect(dialog,contains('if(advanced)TextButton.icon('));
  expect(dialog,contains("Key('waffra-open-backup-file')"));
  expect(dialog,contains('فشل التحقق من صحة الملف'));
  expect(dialog,contains('compute(waffraEncryptBackupInIsolate'));
  expect(dialog,isNot(contains('Clipboard.setData')));
 });
}
