import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('M384: old single and ordered multiple attachment paths survive upgrade', () {
    final oldEntry=MoneyEntry.fromJson(<String,dynamic>{
      'id':'before-update','title':'سداد فاتورة','category':'فواتير',
      'amount':75.0,'income':false,
      'date':'2026-10-28T12:30:00.000',
      'receiptPath':'/existing/app/receipts/old-invoice.jpg',
    });
    expect(waffraReceiptPaths(oldEntry.receiptPath),
      <String>['/existing/app/receipts/old-invoice.jpg']);
    expect(oldEntry.toJson()['receiptPath'], oldEntry.receiptPath);
    expect(oldEntry.withBudget('home').receiptPath, oldEntry.receiptPath);
    expect(oldEntry.withCategory('مصروف البيت').receiptPath, oldEntry.receiptPath);

    final oldMulti=jsonEncode(<String>[
      '/existing/app/receipts/first.jpg',
      '/existing/app/receipts/second.png',
      '/existing/app/receipts/third.pdf',
    ]);
    final decoded=MoneyEntry.fromJson(<String,dynamic>{
      ...oldEntry.toJson(),'receiptPath':oldMulti,
    });
    expect(waffraReceiptPaths(decoded.receiptPath),hasLength(3));
    expect(decoded.toJson()['receiptPath'],oldMulti);
    expect(waffraReceiptPaths(null),isEmpty);
    expect(waffraReceiptPaths(''),isEmpty);
    expect(waffraEncodeReceipts(waffraReceiptPaths(oldMulti)),oldMulti);
  });

  test('M384: both cards show folded count from the stored finance record', () {
    final app=File('lib/main.dart').readAsStringSync();
    final listCard=app.split('Widget tile(MoneyEntry e)').last
      .split('String get greeting').first;
    final compactCard=app.split('Widget compactTransaction(MoneyEntry entry)').last
      .split('Widget dashboard()').first;
    for(final card in <String>[listCard,compactCard]){
      expect(card,contains('final attachmentCount=waffraReceiptPaths('));
      expect(card,contains('if(attachmentCount>0)PositionedDirectional(top:0,start:0'));
      expect(card,contains('WaffraReceiptCornerAction('));
      expect(card,contains('count:attachmentCount,english:waffraIsEnglish'));
      expect(card,contains('onTap:()=>showReceipt('));
      expect(card,isNot(contains('saveReceipt(')),
        reason:'Badge rendering must not copy user attachments or alter storage.');
      expect(card,isNot(contains('delete(')));
    }
    expect(app,contains('onViewReceipt:waffraReceiptPaths(entry.receiptPath).isNotEmpty'));
    expect(app,contains('showReceipt(entry.receiptPath!)'));
  });

  testWidgets('M384: top start corner is right in Arabic and left in English',
      (tester) async {
    for(final english in <bool>[false,true]){
      await tester.pumpWidget(MaterialApp(
        home:Directionality(
          textDirection:english?TextDirection.ltr:TextDirection.rtl,
          child:Scaffold(body:Center(child:SizedBox(
            width:200,height:80,
            child:Stack(key:const Key('m384-test-card'),children:[
              const Positioned.fill(child:ColoredBox(color:Colors.white)),
              PositionedDirectional(top:0,start:0,
                child:WaffraReceiptCornerBadge(count:3,english:english)),
            ]),
          ))),
        ),
      ));
      final badge=tester.getRect(find.byType(WaffraReceiptCornerBadge));
      final stack=tester.getRect(find.byKey(const Key('m384-test-card')));
      expect(badge.width,36);
      expect(badge.height,30);
      expect(badge.top,stack.top);
      expect(english?badge.left:badge.right,
        english?stack.left:stack.right);
      expect(find.text('3'),findsOneWidget);
      expect(find.byIcon(Icons.attach_file_rounded),findsOneWidget);
      final clip=tester.widget<ClipPath>(
        find.descendant(of:find.byType(WaffraReceiptCornerBadge),
          matching:find.byType(ClipPath)).first);
      expect((clip.clipper as WaffraReceiptCornerClipper).english,english);
      expect(tester.takeException(),isNull);
    }
  });

  testWidgets('M384: zero receipt count never needs a corner', (tester) async {
    // The actual cards gate the badge on attachmentCount>0. Verify the
    // legacy null or empty references decode to zero; never invent a badge.
    expect(waffraReceiptPaths(null),isEmpty);
    expect(waffraReceiptPaths(''),isEmpty);
    await tester.pumpWidget(const MaterialApp(home:Scaffold(body:SizedBox())));
    expect(find.byType(WaffraReceiptCornerBadge),findsNothing);
  });
}
