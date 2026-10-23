import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_category_catalog.dart';
import 'package:waffra/waffra_category_english.dart';
import 'package:waffra/waffra_i18n.dart';
import 'package:waffra/waffra_secure_backup.dart';

void main() {
 setUp(()=>waffraLanguage.value='ar');
 tearDown(()=>waffraLanguage.value='ar');

 test('M148: all 76 built-in roots and 690 subcategories have English names',(){
  expect(waffraCategoryCatalog.length,76);
  expect(waffraCategoryCatalog.fold<int>(0,(n,g)=>n+g.subcategories.length),690);
  expect(waffraEnglishCategoryCatalogComplete,isTrue);
  final arabic=RegExp(r'[\u0600-\u06FF]');
  for(final group in waffraCategoryCatalog){
   final en=waffraEnglishCategoryLabel(group.name);
   expect(en,isNot(group.name),reason:'Missing English for '+group.id);
   expect(arabic.hasMatch(en),isFalse,reason:'Untranslated root: '+group.id);
   for(final sub in group.subcategories){
    final subLabel=waffraEnglishCategoryLabel(sub);
    final compound=waffraEnglishCategoryLabel(group.name+' / '+sub);
    expect(arabic.hasMatch(subLabel),isFalse,reason:'Untranslated subcategory: '+sub);
    expect(compound,contains(' / '));
    expect(arabic.hasMatch(compound),isFalse,reason:'Untranslated compound for '+group.id);
   }
  }
 });

 test('M148: English roots outrank same-spelled children; compounds use context',(){
  expect(waffraEnglishCategoryLabel('اشتراكات رقمية'),'Digital Subscriptions');
  expect(waffraEnglishCategoryLabel('دخل رقمي وتقني / اشتراكات رقمية'),
   'Digital & Technology Income / Digital subscriptions');
  expect(waffraEnglishCategoryLabel('هوايات واهتمامات / تصوير'),
   'Hobbies & Interests / Photography');
  expect(waffraEnglishCategoryLabel('عمل حر / تصوير'),
   'Freelance Work / Photography');
 });
 test('M148: changing the display language never mutates stored Arabic names',(){
  final group=waffraCategoryCatalog.first;
  final mainStored=group.name;
  final subStored=group.name+' / '+group.subcategories.first;
  expect(waffraTr(mainStored),mainStored);
  expect(waffraTr(subStored),subStored);
  waffraLanguage.value='en';
  expect(waffraTr(mainStored),'Restaurants & Cafes');
  expect(waffraTr(subStored),'Restaurants & Cafes / Popular restaurants');
  expect(waffraTr('قسم خاص بالمستخدم'),'قسم خاص بالمستخدم');
  expect(mainStored,'مطاعم وكافيهات');
  expect(subStored,'مطاعم وكافيهات / مطاعم شعبية');
 });

 test('M148: transaction pickers and category search use translated display labels',(){
  final main=File('lib/main.dart').readAsStringSync();
  final categories=File('lib/waffra_categories_page.part.dart').readAsStringSync();
  expect(main,contains('waffraTr(item.name).toLowerCase()'));
  expect(main,contains('waffraTr(c.name).toLowerCase()'));
  expect(main,contains('DropdownMenuItem(value:c.name,child:WaffraText(c.name))'));
  expect(main,contains('title:WaffraText(item.name,maxLines:3)'));
  expect(categories,contains('WaffraText(root.name,maxLines:2'));
  expect(categories,contains('WaffraText(sub.displayName,maxLines:2'));
  expect(categories,contains('waffraTr(root.name).toLowerCase()'));
  expect(categories,contains('waffraTr(c.displayName).toLowerCase()'));
  expect(categories,contains('TextSpan(text:waffraTr(sub.displayName)'));
 });

 test('M148: new passwords remain exactly 8; older backups accept long passwords',()async{
  const body='{"format":"waffra-backup","version":24,"entries":[],"categories":[],"goals":[],"recurring":[]}';
  const newPassword='Abcd1234';
  const oldPassword='OldLegacyPass123456';
  expect(WaffraSecureBackup.isValidNewPassword(newPassword),isTrue);
  expect(WaffraSecureBackup.isValidNewPassword(oldPassword),isFalse);
  final newArchive=await WaffraSecureBackup.encryptUserBackup(body,newPassword);
  final oldArchive=await WaffraSecureBackup.encrypt(body,oldPassword);
  final current=await waffraDecodeBackupInIsolate({'payload':newArchive,'password':newPassword});
  final legacy=await waffraDecodeBackupInIsolate({'payload':oldArchive,'password':oldPassword});
  expect(current['format'],'waffra-backup');
  expect(legacy['format'],'waffra-backup');
  await expectLater(
   waffraDecodeBackupInIsolate({'payload':oldArchive,'password':'Wrong123'}),
   throwsA(anything),
  );
  final plain=await waffraDecodeBackupInIsolate({'payload':body,'password':''});
  expect(plain['version'],24);
 });

 test('M148: no full encrypted JSON is rendered in editable TextField',(){
  final source=File('lib/main.dart').readAsStringSync();
  expect(source,contains("Key('waffra-new-backup-password')"));
  expect(source,contains("Key('waffra-existing-backup-password')"));
  expect(source,contains("Key('waffra-open-backup-file')"));
  expect(source,contains("Key('waffra-confirm-backup-restore')"));
  expect(source,contains('LengthLimitingTextInputFormatter(8)'));
  expect(source,contains('stagedBackup=text;'));
  expect(source,contains('compute(waffraDecodeBackupInIsolate'));
  expect(source,contains('WaffraBackupFiles.saveEncryptedArchive(encrypted)'));
  expect(source.contains('await Clipboard.setData(ClipboardData(text:encrypted))'),isFalse);
  expect(source.contains('TextField(controller:input,minLines:4,maxLines:7'),isFalse);
  expect(source.contains('legacyRestorePassword?'),isFalse);
  expect(source,contains("_authorizeSensitiveAction('restoring data')"));
 });
}
