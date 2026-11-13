import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';
import 'package:waffra/main.dart';

void main() {
  test('four finance action destinations share one language-aware circular action', () {
    final source=readWaffraMainSourceForContracts();
    expect(source,contains('floatingActionButtonLocation:WaffraDirectionalFabLocation(english:waffraIsEnglish)'));
    expect(source,contains('floatingActionButton:!ready||accountOpened||tab==2?null:CompositedTransformTarget('));
    expect(source,contains("label:waffraIsEnglish?'New savings goal':'إضافة هدف جديد'"));
    expect(source,contains('bool noTarget=openEnded||(duplicate!=null&&duplicate.target<=0);'));
    expect(source,contains("label:waffraIsEnglish?'Duplicate recurring transaction':'تكرار عملية متكررة موجودة'"));
    expect(source,isNot(contains('key:_tourKeys[1]')));
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

  test('M671 no tour startup/overlay, ordinary Home actions unchanged',(){
    final source=readWaffraMainSourceForContracts();
    expect(source,isNot(contains('tourOverlay()')));
    expect(source,isNot(contains('tourActive')));
    expect(source,isNot(contains('waffra_in_app_tour_seen_v2')));
    expect(source,contains('WaffraStationaryFabAnimator()'));
  });

  test('new backups use 12–256 character passwords and retain legacy import', () {
    final source=readWaffraMainSourceForContracts();
    expect(source,contains("key:const Key('waffra-new-backup-password')"));
    expect(source,contains('LengthLimitingTextInputFormatter(256)'));
    expect(source,contains('Backup password (12+ characters)'));
    expect(source,contains('if(!WaffraSecureBackup.isValidNewPassword(secret.text))'));
    expect(source,contains('WaffraBackupFiles.saveEncryptedArchive(encrypted)'));
    expect(source,contains('WaffraBackupFiles.openArchive()'));
    expect(source,contains("'Import older copied backup (legacy)'"));
    expect(source,contains('Clipboard.getData(Clipboard.kTextPlain)'));
    expect(source,contains('Never copy it to the system clipboard on export.'));
  });

  for (final direction in [TextDirection.rtl,TextDirection.ltr]) {
    testWidgets('physical + follows $direction: Arabic left, English right',(tester) async {
      await tester.binding.setSurfaceSize(const Size(390,760));
      addTearDown(()=>tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home:Directionality(
          textDirection:direction,
          child:Scaffold(
            bottomNavigationBar:const SizedBox(height:85),
            floatingActionButtonLocation:WaffraDirectionalFabLocation(english:direction==TextDirection.ltr),
            floatingActionButton:FloatingActionButton(
              key:const Key('waffra-m127-plus'),
              onPressed:(){},
              child:const Icon(Icons.add),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final rect=tester.getRect(find.byKey(const Key('waffra-m127-plus')));
      if(direction==TextDirection.ltr){
        expect(rect.left,greaterThan(275));
        expect(rect.right,lessThanOrEqualTo(390));
      }else{
        expect(rect.left,greaterThanOrEqualTo(12));
        expect(rect.left,lessThanOrEqualTo(40));
        expect(rect.right,lessThan(120));
      }
      expect(tester.takeException(),isNull);
    });
  }
}
