import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_backup_files.dart';
import 'package:waffra/waffra_category_catalog.dart';
import 'package:waffra/waffra_secure_backup.dart';

void main(){
 test('M150: deleted categories label always shows current count, including zero',(){
  final source=File('lib/waffra_categories_page.part.dart').readAsStringSync();
  expect(source,contains("'Deleted categories (" ));
  expect(source,contains("deletedCategories.length"));
  expect(source,contains("الأقسام المحذوفة ("));
  expect(source,contains('WaffraDeletedItemsButton('));
 });

 test('M150: manual income/expense picker receives only leaf categories',(){
  final source=File('lib/main.dart').readAsStringSync();
  expect(source,contains('List<BudgetCategory> forManualTransactionType(bool income)=>'));
  expect(source,contains('c.income==income&&c.isSubcategory'));
  expect(source,contains('final mainCategories=waffraManualCategoryParents(available,income);'));
  expect(source,contains('final subcategories=waffraManualCategoryChildren(available,income,selectedParentId);'));
  expect(source,contains('parentId:mainId'));
  expect(source,contains("onTap:()=>Navigator.pop(dialogCtx,item.name)"));
  expect(waffraCategoryCatalog.isNotEmpty,isTrue);
  expect(source,contains('waffraCanAssignManualCategory(categories,'));
 });

 test('M150: archive filename is safe and uses .waffra extension',(){
  expect(WaffraBackupFiles.suggestedName(DateTime(2026,10,23,18,45,3)),
   'Waffra_Backup_2026-10-23_184503.waffra');
 });

 test('M150: file bridge refuses plaintext financial archives',()async{
  const raw='{"format":"waffra-backup","entries":[{"amount":50}]}';
  expect(WaffraBackupFiles.isEncryptedArchive(raw),isFalse);
  expect(WaffraBackupFiles.isEncryptedArchive('invalid-json'),isFalse);
  final protected=await WaffraSecureBackup.encryptUserBackup(raw,'LongPassphrase123!');
  expect(WaffraBackupFiles.isEncryptedArchive(protected),isTrue);
  expect(await WaffraSecureBackup.decrypt(protected,'LongPassphrase123!'),raw);
 });

 test('M150: export never writes encrypted archive to clipboard',(){
  final source=File('lib/main.dart').readAsStringSync();
  final start=source.indexOf('Future<void> backupDialog()');
  final end=source.indexOf('// System credentials are never saved',start);
  expect(start,greaterThan(-1));
  expect(end,greaterThan(start));
  final dialog=source.substring(start,end);
  expect(dialog,contains('WaffraBackupFiles.saveEncryptedArchive(encrypted)'));
  expect(dialog,contains("Key('waffra-open-backup-file')"));
  expect(dialog,contains('WaffraBackupFiles.openArchive()'));
  expect(dialog,contains("Key('waffra-import-legacy-text')"));
  expect(dialog,contains('compute(waffraDecodeBackupInIsolate'));
  expect(dialog.contains('Clipboard.setData'),isFalse);
  expect(dialog.contains('ClipboardData(text:encrypted)'),isFalse);
  expect(dialog.contains('TextField(controller:input,minLines:4,maxLines:7'),isFalse);
 });

 test('M150: Android uses picker and content provider (never storage permission)',(){
  final native=File('native/WaffraMainActivity.kt').readAsStringSync();
  expect(native,contains('waffra/backup_files'));
  expect(native,contains('Intent.ACTION_CREATE_DOCUMENT'));
  expect(native,contains('Intent.ACTION_OPEN_DOCUMENT'));
  expect(native,contains('Intent.CATEGORY_OPENABLE'));
  expect(native,contains('contentResolver.openOutputStream'));
  expect(native,contains('contentResolver.openInputStream'));
  expect(native,contains('pendingBackupBytes?.fill(0)'));
  expect(native,contains('backupMaxBytes = 8 * 1024 * 1024'));
  expect(native.contains('READ_EXTERNAL_STORAGE'),isFalse);
  expect(native.contains('WRITE_EXTERNAL_STORAGE'),isFalse);
  expect(native.contains('ClipboardManager'),isFalse);
 });
}
