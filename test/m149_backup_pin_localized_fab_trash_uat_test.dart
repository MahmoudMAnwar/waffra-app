import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_i18n.dart';
import 'package:waffra/waffra_secure_backup.dart';

void main() {
 setUp(()=>waffraLanguage.value='ar');
 tearDown(()=>waffraLanguage.value='ar');

 test('M149: export and restore passwords use exactly identical 8-char rules',(){
  final source=File('lib/main.dart').readAsStringSync();
  final start=source.indexOf('Future<void> backupDialog()');
  final end=source.indexOf('// System credentials are never saved',start);
  expect(start,greaterThan(-1));
  expect(end,greaterThan(start));
  final dialog=source.substring(start,end);
  final newField=dialog.substring(
   dialog.indexOf("Key('waffra-new-backup-password')"),
   dialog.indexOf("Key('waffra-new-backup-password')")+380);
  final restoreField=dialog.substring(
   dialog.indexOf("Key('waffra-existing-backup-password')"),
   dialog.indexOf("Key('waffra-existing-backup-password')")+420);
  for(final field in [newField,restoreField]){
   expect(field,contains('LengthLimitingTextInputFormatter(8)'));
   expect(field,contains("RegExp(r'[A-Za-z0-9]')"));
   expect(field,contains('obscureText:true'));
  }
  expect(dialog,contains('WaffraSecureBackup.isValidNewPassword(restoreSecret.text)'));
  expect(dialog,contains('WaffraSecureBackup.isValidNewPassword(secret.text)'));
  expect(dialog,contains('compute(waffraDecodeBackupInIsolate'));
  expect(dialog.contains('TextField(controller:input,minLines:4,maxLines:7'),isFalse);
  expect(WaffraSecureBackup.isValidNewPassword('Abcd1234'),isTrue);
  expect(WaffraSecureBackup.isValidNewPassword('Abcd12345'),isFalse);
  expect(WaffraSecureBackup.isValidNewPassword('Abcdefgh'),isFalse);
  expect(WaffraSecureBackup.isValidNewPassword('12345678'),isFalse);
 });

 test('M149: initial PIN advances on four digits and three dialogs use same shell',(){
  final source=File('lib/main.dart').readAsStringSync();
  final start=source.indexOf('Future<String?> _askForPin(');
  final end=source.indexOf('Future<void> configurePin()',start);
  expect(start,greaterThan(-1));
  expect(end,greaterThan(start));
  final dialog=source.substring(start,end);
  expect(dialog,contains('bool autoAdvance=false'));
  expect(dialog,contains('if(autoAdvance&&value.length==4'));
  expect(dialog,contains('Navigator.pop(dialogContext,value)'));
  expect(dialog,contains('if(!autoAdvance)FilledButton('));
  expect(dialog,contains("waffraIsEnglish?'Cancel':'إلغاء'"));
  expect(dialog,contains("waffraIsEnglish?'Confirm':'تأكيد'"));
  expect(dialog,contains("Key('waffra-pin-input')"));
  expect(dialog,contains('Colors.white.withValues(alpha:.12)'));
  expect(dialog.contains("helperText:existing?"),isFalse);
  expect(source,contains("autoAdvance:true"));
  expect(source,contains("waffraIsEnglish?'Confirm PIN':'تأكيد رمز القفل'"));
  expect(source,contains('if(verify!=null&&!verify(code))'));
  expect(source,contains('await widget.onSetPin(firstPin)'));
 });

 test('M149: all recycle-bin CTAs are red and recurring calendar is alongside',(){
  final main=File('lib/main.dart').readAsStringSync();
  final cats=File('lib/waffra_categories_page.part.dart').readAsStringSync();
  expect(main,contains('class WaffraDeletedItemsButton extends StatelessWidget'));
  expect(main,contains('const Color(0xFFFF9090)'));
  expect(main,contains('const Color(0xFFB42332)'));
  expect(main,contains('onPressed:deletedGoalsDialog'));
  expect(main,contains('onPressed:deletedRecurringDialog'));
  expect(main,contains('Expanded(child:WaffraDeletedItemsButton('));
  expect(main,contains('Expanded(child:OutlinedButton('));
  expect(main,contains('onPressed:showWaffraFinancialCalendar'));
  expect(cats,contains('onPressed:showCategoryTrash'));
  expect(cats,contains('WaffraDeletedItemsButton('));
 });

 for(final brightness in [Brightness.light,Brightness.dark]){
  testWidgets('M149: red deleted button fits narrow half-width in $brightness',(tester)async{
   await tester.binding.setSurfaceSize(const Size(320,700));
   addTearDown(()=>tester.binding.setSurfaceSize(null));
   await tester.pumpWidget(MaterialApp(
    theme:ThemeData(brightness:brightness,fontFamily:'Tajawal',useMaterial3:true),
    home:Scaffold(body:Center(child:SizedBox(width:148,child:
     WaffraDeletedItemsButton(onPressed:(){},
      label:'العمليات المتكررة المحذوفة (0)'))))));
   await tester.pumpAndSettle();
   expect(find.byIcon(Icons.delete_outline),findsOneWidget);
   expect(find.text('العمليات المتكررة المحذوفة (0)'),findsWidgets);
   expect(tester.takeException(),isNull);
  });
 }
}
