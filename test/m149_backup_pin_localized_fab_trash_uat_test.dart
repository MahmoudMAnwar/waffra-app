import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_action_layout.dart';
import 'package:waffra/waffra_i18n.dart';
import 'package:waffra/waffra_secure_backup.dart';

void main() {
 setUp(()=>waffraLanguage.value='ar');
 tearDown(()=>waffraLanguage.value='ar');

 test('M149: V2 uses strong passphrase; legacy restore accepts old password',(){
  final source=File('lib/main.dart').readAsStringSync();
  final start=source.indexOf('Future<void> backupDialog()');
  final end=source.indexOf('// System credentials are never saved',start);
  final dialog=source.substring(start,end);
  expect(dialog,contains('LengthLimitingTextInputFormatter(256)'));
  expect(dialog,contains('WaffraSecureBackup.isValidNewPassword(secret.text)'));
  expect(dialog,contains('if(restoreSecret.text.isEmpty)'));
  expect(dialog,contains('compute(waffraDecodeBackupInIsolate'));
  expect(dialog,contains("Key('waffra-backup-choose-export')"));
  expect(dialog,contains("Key('waffra-backup-choose-restore')"));
  expect(WaffraSecureBackup.isValidNewPassword('Abcd1234'),isFalse);
  expect(WaffraSecureBackup.isValidNewPassword('A very long passphrase!'),isTrue);
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
  expect(main,contains('onPressed:WaffraHaptics.tapRequired(deletedGoalsDialog)'));
  expect(main,contains('onPressed:WaffraHaptics.tapRequired(deletedRecurringDialog)'));
  // The new compact recurring cards remain adjacent; legacy recycle-bin
  // buttons in other sections stay red and independently accessible.
  expect(main,contains("Key('waffra-recurring-count-badge')"));
  expect(main,contains('Expanded(child:OutlinedButton.icon('));
  expect(main,contains('onPressed:WaffraHaptics.tapRequired(deletedRecurringDialog)'));
  // Compact buttons retain the 48dp minimum touch target
  // without reintroducing oversized outlines.
  expect(main,contains('minimumSize:WaffraActionLayout.minimumSize'));
  expect(WaffraActionLayout.minimumSize.height,greaterThanOrEqualTo(48));
  expect(main,contains('onPressed:WaffraHaptics.tap(showWaffraFinancialCalendar)'));
  expect(cats,contains('onPressed:WaffraHaptics.tapRequired(showCategoryTrash)'));
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
