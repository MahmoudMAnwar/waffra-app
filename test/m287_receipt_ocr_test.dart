import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:waffra/waffra_practical_ledger_engine.dart';
import 'package:waffra/waffra_practical_tools_page.dart';
import 'package:waffra/waffra_receipt_ocr_parser.dart';

void main() {
  test('M287 Arabic digits, bilingual total and dates are parsed correctly', () {
    final result = WaffraReceiptOcrParser.parse(
      'أسواق الدانوب\nفاتورة ضريبية\n'
      'التاريخ: ٢٧/١٠/٢٠٢٦\n'
      'ضريبة القيمة المضافة ١٥٫٠٠\n'
      'الإجمالي: ١١٥٫٠٠ ريال',
    );
    expect(result.merchant, 'أسواق الدانوب');
    expect(result.amount, 115.00);
    expect(result.date, DateTime(2026, 10, 27));
  });

  test('M287 VAT and subtotal cannot override final English grand total', () {
    final result = WaffraReceiptOcrParser.parse(
      'Market One\nTAX INVOICE\n'
      'Date: 2026-10-27\n'
      'SUBTOTAL 1,000.00\n'
      'VAT 150.00\n'
      'GRAND TOTAL SAR 1,150.00',
    );
    expect(result.merchant, 'Market One');
    expect(result.amount, 1150);
    expect(result.date, DateTime(2026, 10, 27));
  });

  test('M287 money parsing accepts localized grouping and rejects bad values', () {
    expect(WaffraReceiptOcrParser.amountFromText('١٬٢٣٤٫٥٠'), 1234.50);
    expect(WaffraReceiptOcrParser.amountFromText('1.234,50'), 1234.50);
    expect(WaffraReceiptOcrParser.amountFromText('1,234.50'), 1234.50);
    expect(WaffraReceiptOcrParser.amountFromText('25,15'), 25.15);
    expect(WaffraReceiptOcrParser.amountFromText('1.234.567'), 1234567);
    expect(WaffraReceiptOcrParser.amountFromText('25.155'), isNull);
    expect(WaffraReceiptOcrParser.amountFromText('0'), isNull);
    expect(WaffraReceiptOcrParser.amountFromText('-12.00'), isNull);
    expect(WaffraReceiptOcrParser.amountFromText('abc'), isNull);
  });

  test('M287 unreadable receipt returns empty suggestions without inventing data', () {
    final result = WaffraReceiptOcrParser.parse('   \n ');
    expect(result.hasSuggestions, isFalse);
    expect(result.merchant, isNull);
    expect(result.amount, isNull);
    expect(result.date, isNull);
  });

  test('M287 date validator never converts invalid dates into future dates', () {
    final result = WaffraReceiptOcrParser.parse(
      'Store Name\nDate: 31/02/2026\nTotal 44.60');
    expect(result.date, isNull);
    expect(result.amount, 44.60);
  });

  for (final english in <bool>[false, true]) {
    testWidgets('M287 gallery starts OCR and prefills editable receipt fields; english=$english',
        (tester) async {
      tester.view.physicalSize = const Size(393, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      var pathSeen = '';
      await tester.pumpWidget(MaterialApp(home: WaffraPracticalToolsPage(
        english: english, entries: const <WaffraPracticalEntry>[],
        pickImage: (source) async {
          expect(source, ImageSource.gallery);
          return XFile('/tmp/qa-synthetic-receipt.jpg');
        },
        scanReceipt: (path) async {
          calls++;
          pathSeen = path;
          return WaffraReceiptOcrParser.parse(
            'Corner Coffee\nDate: 2026-10-27\nGrand Total SAR 42.75');
        },
      )));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('m281-receipt-tile')));
      await tester.tap(find.byKey(const Key('m281-receipt-tile')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(english ? 'Choose image' : 'اختيار صورة'));
      await tester.tap(find.text(english ? 'Choose image' : 'اختيار صورة'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(pathSeen, '/tmp/qa-synthetic-receipt.jpg');
      expect(find.byKey(const Key('m287-ocr-result')), findsOneWidget);
      expect(tester.widget<TextField>(
        find.byKey(const Key('m281-receipt-merchant'))).controller!.text,
        'Corner Coffee');
      expect(tester.widget<TextField>(
        find.byKey(const Key('m281-receipt-amount'))).controller!.text,
        '42.75');
      await tester.ensureVisible(find.text(
        english ? 'Validate receipt draft' : 'التحقق من بيانات الفاتورة'));
      await tester.tap(find.text(
        english ? 'Validate receipt draft' : 'التحقق من بيانات الفاتورة'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('m281-receipt-reviewed')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('M287 broken OCR shows actionable failure and keeps manual review',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: WaffraPracticalToolsPage(
      english: false, entries: const <WaffraPracticalEntry>[],
      pickImage: (_) async => XFile('/tmp/qa-synthetic-receipt.jpg'),
      scanReceipt: (_) async => throw const FormatException('bad bitmap'),
    )));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('m281-receipt-tile')));
    await tester.tap(find.byKey(const Key('m281-receipt-tile')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('اختيار صورة'));
    await tester.tap(find.text('اختيار صورة'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('m281-receipt-picker-error')), findsOneWidget);
    expect(find.byKey(const Key('m281-receipt-merchant')), findsOneWidget);
    expect(find.byKey(const Key('m281-receipt-amount')), findsOneWidget);
  });
}
