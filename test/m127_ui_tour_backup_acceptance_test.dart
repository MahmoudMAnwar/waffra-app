import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_i18n.dart';

void main() {
  test('four finance destinations share language-aware circular add action', () {
    final source=File('lib/main.dart').readAsStringSync();
    expect(source,contains('floatingActionButtonLocation:const WaffraLanguageAwareFabLocation()'));
    expect(source,contains('floatingActionButton:!ready||tab==4?null:Directionality('));
    expect(source,contains('if(goalsOpened||tab==2){goalDialog();return;}'));
    expect(source,contains('if(tab==3){recurringDialog();return;}'));
    expect(source,contains('child:SizedBox(key:_tourKeys[1],width:58,height:58'));
    expect(source.contains('onTap:()=>setState(()=>addFabExpanded=!addFabExpanded)'),
        isFalse);
    final goalsStart=source.indexOf('Widget goalsPage()');
    final recurringStart=source.indexOf('Widget recurringPage()');
    expect(goalsStart,greaterThanOrEqualTo(0));
    expect(recurringStart,greaterThan(goalsStart));
    final goalSection=source.substring(goalsStart,recurringStart);
    expect(goalSection.contains('FilledButton.icon(onPressed:goalDialog'),false);
    final recurringEnd=source.indexOf('Future<void> showWaffraFinancialCalendar()',recurringStart);
    expect(recurringEnd,greaterThan(recurringStart));
    final recurringSection=source.substring(recurringStart,recurringEnd);
    expect(recurringSection.contains('FilledButton.icon(onPressed:recurringDialog'),false);
    expect(recurringSection.contains('OutlinedButton.icon(onPressed:recurringDialog'),false);
  });

  test('tour intro no longer cuts through the top header', () {
    final source=File('lib/main.dart').readAsStringSync();
    expect(source,contains('tourStep==0?Rect.fromLTWH(-40,-40,1,1)'));
    expect(source,contains('final suggestedTop=tourStep==0?'));
    expect(source,contains('final suggestedLeft=tourStep==0?'));
    expect(source,contains('if(tourActive&&tourTargetReady)Positioned.fill(child:tourOverlay())'));
  });

  test('both backup export and restore fields are capped at eight', () {
    final source=File('lib/main.dart').readAsStringSync();
    expect(source,contains('LengthLimitingTextInputFormatter(8)'));
    expect(source,contains("RegExp(r'[A-Za-z0-9]')"));
    expect(source,contains('if(!WaffraSecureBackup.isValidNewPassword(secret.text))'));
    expect(source,contains("Key('waffra-existing-backup-password')"));
    expect(source,contains("Key('waffra-open-backup-file')"));
    expect(source,contains('compute(waffraDecodeBackupInIsolate'));
    expect(source,contains('WaffraBackupFiles.saveEncryptedArchive(encrypted)'));
    expect(source.contains('await Clipboard.setData(ClipboardData(text:encrypted))'),isFalse);
    expect(source.contains('legacyRestorePassword?'),isFalse);
    expect(source.contains('TextField(controller:input,minLines:4,maxLines:7'),isFalse);
  });

  for (final language in ['ar','en']) {
    testWidgets('floating + goes to the correct physical side in $language',(tester) async {
      waffraLanguage.value=language;
      addTearDown(()=>waffraLanguage.value='ar');
      await tester.binding.setSurfaceSize(const Size(390,760));
      addTearDown(()=>tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home:Directionality(
          textDirection:language=='ar'?TextDirection.rtl:TextDirection.ltr,
          child:Scaffold(
            bottomNavigationBar:const SizedBox(height:85),
            floatingActionButtonLocation:const WaffraLanguageAwareFabLocation(),
            floatingActionButton:FloatingActionButton(
              key:const Key('waffra-m127-plus'),onPressed:(){},
              child:const Icon(Icons.add)),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final rect=tester.getRect(find.byKey(const Key('waffra-m127-plus')));
      if(language=='ar'){
       expect(rect.left,inInclusiveRange(12,45));
       expect(rect.right,lessThan(120));
      }else{
       expect(rect.right,inInclusiveRange(345,390));
       expect(rect.left,greaterThan(270));
      }
      expect(tester.takeException(),isNull);
    });
  }
}
