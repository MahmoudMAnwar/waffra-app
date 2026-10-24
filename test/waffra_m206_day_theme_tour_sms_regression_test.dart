import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';

void main() {
  test('new installs start in light mode while an explicit choice persists', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains("String appearance='light';"));
    expect(source, contains(
      "appearance=p.getString('waffra_appearance_mode_v1')??"));
    expect(source, contains(
      "if(!{'light','dark','system'}.contains(appearance))appearance='light';"));
  });

  test('replayable tour only includes six core screens', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('static const tourTabs=<int>[0,0,0,1,2,3];'));
    expect(source, contains('static const tourTargetKeys=<int>[-1,0,1,2,6,4];'));
    final tour = source.substring(source.indexOf('Widget tourOverlay()=>'),
      source.indexOf('Future<void> changePin()', source.indexOf('Widget tourOverlay()=>')));
    expect(tour, isNot(contains('التحليل المالي الذكي')));
    expect(tour, isNot(contains('حسابي وإعداداتي')));
    expect(tour, contains("'${tourStep+1}/${tourTabs.length}'"));
  });

  test('all confirmed SMS routes persist full text as notes, not title', () {
    final home = File('lib/main.dart').readAsStringSync();
    final widget = File('lib/waffra_widget_capture.part.dart').readAsStringSync();
    expect(home, contains("date:bankSmsDate(raw)??DateTime.now(),notes:raw,sourceType:'sms'"));
    expect(home, contains('date:now,notes:messages[index],sourceType:'));
    expect(home, contains('notes:sms?message.text:notes.text'));
    expect(widget, contains('notes:entry.raw,sourceType:'));
    expect(widget, contains('waffraSafeSmsTransactionTitle(parsed.title,entry.raw'));
    expect(home, contains('child:SelectableText(entry.notes'));
  });

  test('FAB launch waits for the menu collapse and suppresses double taps', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('if(_addActionOpening)return;'));
    expect(source, contains('if(fromMenu)await Future<void>.delayed(waffraMotion(260));'));
    expect(source, contains('if(!_acceptFabTap())return;'));
    expect(source, contains('splashFactory:NoSplash.splashFactory'));
    expect(source, contains('key:_tourKeys[1]'));
  });

  testWidgets('details show entire notes and keep concise name', (tester) async {
    const raw = 'عملية شراء\nبمبلغ 84.72 ريال\nتاريخ 2026/10/24\nمرجع ABC123\nرصيد متبقٍ 900 ريال';
    final entry = MoneyEntry(
      id:'m206-test', title:'شراء - متجر', category:'تسوق', amount:84.72,
      income:false, date:DateTime(2026,10,24), notes:raw, sourceType:'sms');
    await tester.pumpWidget(MaterialApp(
      home:Scaffold(body:WaffraTransactionDetailsDialog(
        entry:entry, onClose:(){},
      )),
    ));
    expect(find.text('شراء - متجر'),findsOneWidget);
    expect(find.text(raw),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
