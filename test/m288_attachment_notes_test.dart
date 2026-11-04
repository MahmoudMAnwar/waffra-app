import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_receipt_filename.dart';
import 'package:waffra/waffra_i18n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('M288 attachment label validates names', () {
    expect(WaffraReceiptFilename.validateLabel('فاتورة السوبرماركت'), isNull);
    expect(WaffraReceiptFilename.validateLabel('Invoice October'), isNull);
    expect(WaffraReceiptFilename.validateLabel(''), isNotNull);
    expect(WaffraReceiptFilename.validateLabel('   '), isNotNull);
    expect(WaffraReceiptFilename.validateLabel('../private'), isNotNull);
    expect(WaffraReceiptFilename.validateLabel(r'invoice\secret'), isNotNull);
    expect(WaffraReceiptFilename.validateLabel('bad\nname'), isNotNull);
    expect(WaffraReceiptFilename.validateLabel(
      List<String>.filled(81,'x').join()), isNotNull);
    expect(WaffraReceiptFilename.normalizedLabel(' فاتورة__تجريبية  '),
        'فاتورة_تجريبية');
  });

  test('M288 legacy path and original extension remain readable', () {
    expect(WaffraReceiptFilename.displayName('/data/receipts/123__receipt.jpg'),
        'receipt');
    expect(WaffraReceiptFilename.displayName('/data/receipts/receipt.png'),
        'receipt');
    expect(WaffraReceiptFilename.displayName('/data/receipts/a1__فاتورة مطعم.jpeg'),
        'فاتورة مطعم');
    final original = '/data/receipts/123__old.png';
    expect(waffraReceiptPaths(waffraEncodeReceipts([original])), [original]);
    expect(waffraReceiptPaths(waffraEncodeReceipts([
      original, '/data/receipts/456__renamed.png',
    ])), hasLength(2));
  });

  test('M288 renamed staged copy preserves bytes and original on cancel',
      () async {
    final base = await Directory.systemTemp.createTemp('waffra-m288-');
    addTearDown(() async {
      if (await base.exists()) await base.delete(recursive: true);
    });
    final receipts = Directory('${base.path}/receipts')
      ..createSync(recursive: true);
    final original = File('${receipts.path}/123__old.jpg')
      ..writeAsBytesSync(utf8.encode('fake-fixture-image-binary'));
    final renamed = await WaffraReceiptFilename.stageCopyWithName(
      sourcePath: original.path,
      appReceiptsDirectory: receipts.path,
      proposedLabel: 'فاتورة متجر أكتوبر',
    );
    expect(renamed, isNot(original.path));
    expect(WaffraReceiptFilename.displayName(renamed), 'فاتورة متجر أكتوبر');
    expect(renamed, endsWith('.jpg'));
    expect(await File(renamed).readAsBytes(), await original.readAsBytes());
    expect(await original.exists(), isTrue);
    await File(renamed).delete();
    expect(await original.exists(), isTrue);
  });

  test('M288 external path cannot escape private receipts directory', () async {
    final base = await Directory.systemTemp.createTemp('waffra-m288-scope-');
    addTearDown(() async {
      if (await base.exists()) await base.delete(recursive: true);
    });
    final receipts = Directory('${base.path}/receipts')
      ..createSync(recursive: true);
    final outsider = File('${base.path}/outsider.jpg')
      ..writeAsBytesSync([1, 2, 3]);
    await expectLater(
      WaffraReceiptFilename.stageCopyWithName(
        sourcePath: outsider.path,
        appReceiptsDirectory: receipts.path, proposedLabel: 'outside',
      ),
      throwsA(isA<FileSystemException>()),
    );
  });

  MoneyEntry record(String notes, {String source = 'manual'}) => MoneyEntry(
    id:'test-1', title:'متجر تجريبي',category:'تسوق',
    amount: 25.50, income:false,
    date:DateTime(2026,10,27),notes:notes,sourceType:source);
  Widget details(MoneyEntry entry) => MaterialApp(
    home:Scaffold(body:WaffraTransactionDetailsDialog(
      entry:entry,onClose:(){},
      protectedOriginalSms: 'BANK ORIGINAL - fake synthetic SMS',
    )));

  testWidgets('M288 empty or whitespace notes hidden, without hiding SMS',
      (tester) async {
    waffraLanguage.value='ar';
    for(final notes in <String>['', ' ', '\n \t']) {
      await tester.pumpWidget(details(record(notes,source:'sms')));
      await tester.pump();
      expect(find.text('الملاحظات'), findsNothing);
      expect(find.text('لا توجد ملاحظات'), findsNothing);
      expect(find.byKey(const Key('waffra-transaction-personal-notes')),
          findsNothing);
      expect(find.byKey(const Key('waffra-transaction-protected-bank-sms')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(details(record('ملاحظة يدوية')));
    // WaffraText wraps a Text; both nodes match the same visible label.
    expect(find.text('الملاحظات'), findsWidgets);
    expect(find.byKey(const Key('waffra-transaction-personal-notes')),
        findsOneWidget);
  });
}
