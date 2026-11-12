import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_riyal_symbol.dart';
import 'package:waffra/waffra_i18n.dart';

void main() {
  const style = TextStyle(fontSize: 14);

  test('M470 Arabic SMS words after digits are never currency units', () {
    for (final text in <String>[
      '497 رسالة تحتاج فرز',
      '500 رسائل من مرسلين',
      '3 رسائل بانتظار المراجعة',
      '500 رسالة من AlinmaPay',
      '9288\nرسوم مستقلة: لا توجد',
      '200 رسم مطلوب',
      '150 رسومات أخرى',
      '100 رسالة بنكية',
    ]) {
      expect(waffraMoneyCurrencySpans(text, english: false, style: style),
          isNull, reason: text);
    }
  });

  test('M470 transfer fee renders exactly one valid SAR mark', () {
    const text = 'من الحساب: ••••8308\n'
        'إلى الحساب: ••••9288\n'
        'رسوم مستقلة: 0.58 SAR';
    final spans = waffraMoneyCurrencySpans(
        text, english: false, style: style);
    expect(spans, isNotNull);
    expect(spans!.whereType<WidgetSpan>().length, 1);
    final words = spans.whereType<TextSpan>()
        .map((span) => span.text ?? '').join();
    expect(words, contains('رسوم مستقلة: '));
    expect(words, contains('9288'));
  });

  test('M470 whole Riyal units remain supported without false words', () {
    for (final unit in <String>[
      'SAR', 'SR', 'ر.س', 'ر س', 'ريال', 'ريال سعودي', '﷼', '⃁',
    ]) {
      final spans = waffraMoneyCurrencySpans(
          '135.00 $unit', english: false, style: style);
      expect(spans, isNotNull, reason: unit);
      expect(spans!.whereType<WidgetSpan>().length, 1, reason: unit);
    }
  });

  test('M470 mixed Arabic and English sender text stays intact', () {
    const text = '500 رسالة من AlinmaPay و497 رسالة من Etimad';
    expect(waffraMoneyCurrencySpans(text, english: false, style: style),
        isNull);
    final valid = waffraMoneyCurrencySpans(
        'رسالة واردة: SAR 135.00', english: false, style: style);
    expect(valid, isNotNull);
    expect(valid!.whereType<WidgetSpan>().length, 1);
    expect(valid.whereType<TextSpan>()
        .map((span) => span.text ?? '').join(),
        contains('رسالة واردة: '));
  });

  testWidgets('M470 bank SMS counter and fee labels are never mutilated',
      (tester) async {
    waffraLanguage.value = 'ar';
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: Column(children: [
        WaffraText('497 رسائل بانتظار المراجعة'),
        WaffraText('500 رسالة من مرسلين'),
        WaffraText('رسوم مستقلة: 0.58 SAR'),
      ]),
    )));
    // The one real SAR amount uses the image, but the counter words never do.
    expect(find.byType(WaffraCurrencyMark), findsOneWidget);
    expect(find.byWidgetPredicate((widget) =>
        widget is Text && widget is! WaffraText &&
        widget.data == '497 رسائل بانتظار المراجعة'), findsOneWidget);
    expect(find.byWidgetPredicate((widget) =>
        widget is Text && widget is! WaffraText &&
        widget.data == '500 رسالة من مرسلين'), findsOneWidget);
    addTearDown(() => waffraLanguage.value = 'ar');
  });

  test('M666 English money also uses visual official SAR mark', () {
    final spans = waffraMoneyCurrencySpans(
        'Amount 135.00 SAR', english: true, style: style);
    expect(spans, isNotNull);
    expect(spans!.whereType<WidgetSpan>().length, 1);
    expect(spans.whereType<TextSpan>()
        .map((span) => span.text ?? '').join(), 'Amount ');
  });
}
