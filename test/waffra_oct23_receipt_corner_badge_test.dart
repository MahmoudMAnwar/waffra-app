import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Transaction cards use a tappable numbered attachment corner badge', () {
    final app = File('lib/main.dart').readAsStringSync();
    final fullStart = app.indexOf(' Widget tile(MoneyEntry e){');
    final fullEnd = app.indexOf(' String get greeting', fullStart);
    final compactStart = app.indexOf(' Widget compactTransaction(MoneyEntry entry){');
    final compactEnd = app.indexOf(' Widget dashboard(){', compactStart);

    expect(fullStart, greaterThanOrEqualTo(0));
    expect(fullEnd, greaterThan(fullStart));
    expect(compactStart, greaterThanOrEqualTo(0));
    expect(compactEnd, greaterThan(compactStart));

    final cards = [
      app.substring(fullStart, fullEnd),
      app.substring(compactStart, compactEnd),
    ];
    for (final card in cards) {
      expect(card, contains('final attachmentCount=waffraReceiptPaths('));
      expect(card, contains('if(attachmentCount>0)PositionedDirectional(top:0,end:0'));
      expect(card, contains("Text('\$attachmentCount'"));
      expect(card, contains('onTap:()=>showReceipt('));
      expect(card, contains('عدد المرفقات \$attachmentCount'));
    }

    final compact = cards.last;
    expect(compact, isNot(contains('if(waffraReceiptPaths(entry.receiptPath).length>1)')));
    expect(compact, isNot(contains('Icon(Icons.attach_file_rounded,size:17')));
    expect(compact, contains('clipBehavior:Clip.antiAlias'));
    expect(compact, contains('top:attachmentCount>0?18:0'));
  });
}
