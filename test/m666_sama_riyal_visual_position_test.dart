import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_i18n.dart';
import 'package:waffra/waffra_riyal_symbol.dart';

/// M666: SAMA pp. 16–17 require physical LEFT mark position in BOTH locales,
/// with a visible gap, including before the minus sign. These assertions
/// inspect real Flutter geometry, not only the string concatenation order.
void main() {
  setUp(() => waffraLanguage.value = 'ar');
  tearDown(() => waffraLanguage.value = 'ar');

  Finder directText(Finder scope, String value) => find.descendant(
    of: scope,
    matching: find.byWidgetPredicate((widget) =>
      widget is Text && widget is! WaffraText && widget.data == value),
  );

  void assertMarkToLeft(WidgetTester tester, Finder scope, String amount) {
    final mark = find.descendant(
      of: scope, matching: find.byType(WaffraCurrencyMark));
    final number = directText(scope, amount);
    expect(mark, findsOneWidget);
    expect(number, findsOneWidget);
    final markRight = tester.getTopLeft(mark).dx + tester.getSize(mark).width;
    final amountLeft = tester.getTopLeft(number).dx;
    expect(markRight, lessThan(amountLeft),
      reason: 'Saudi symbol must be physically left of signed amount');
    final image = find.descendant(of: mark, matching: find.byType(Image));
    expect(image, findsOneWidget);
    expect((tester.widget<Image>(image).image as AssetImage).assetName,
      waffraRiyalAsset);
  }

  for (final english in <bool>[false, true]) {
    testWidgets('M666 ${english ? "English LTR" : "Arabic RTL"} mark-left for '
      'signed Home amounts and inline SAR', (tester) async {
      waffraLanguage.value = english ? 'en' : 'ar';
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(home: Directionality(
        textDirection: english ? TextDirection.ltr : TextDirection.rtl,
        child: const Scaffold(body: Column(children: [
          SizedBox(key: Key('m666-home-balance'),
            child: RiyalAmount(-1234.50)),
          SizedBox(key: Key('m666-inline-expense'),
            child: WaffraText('رسوم: -1,234.50 ريال')),
          SizedBox(key: Key('m666-inline-prefix'),
            child: WaffraText('رصيد: SAR 1,234.50')),
        ])),
      )));
      await tester.pump();
      assertMarkToLeft(tester, find.byKey(const Key('m666-home-balance')),
        '-1,234.50');
      assertMarkToLeft(tester, find.byKey(const Key('m666-inline-expense')),
        '-1,234.50');
      assertMarkToLeft(tester, find.byKey(const Key('m666-inline-prefix')),
        '1,234.50');
      expect(tester.takeException(), isNull);
    });
  }

  test('M666 money replacement ignores prose, SMS counters and other FX codes', () {
    const style = TextStyle(fontSize: 15);
    for (final text in <String>[
      'كل ريال تحسب له حساب',
      '497 رسالة بانتظار المراجعة',
      '500 رسائل',
      'المبلغ 250 EGP',
      'USD 50.00',
    ]) {
      expect(waffraMoneyCurrencySpans(text, english: false, style: style),
        isNull, reason: text);
    }
    for (final text in <String>[
      '0 ريال', '-1,234.50 ريال', 'SAR 123.00', '١٢٣٫٥٠ ر.س',
    ]) {
      expect(waffraMoneyCurrencySpans(text, english: true, style: style)
        ?.whereType<WidgetSpan>().length, 1, reason: text);
    }
  });

  test('M666 PDF money uses official asset and fixed LTR symbol-before-text', () {
    final main = File('lib/main.dart').readAsStringSync();
    final start = main.indexOf('pw.Widget pdfMoney(String text,');
    final end = main.indexOf('pw.Widget pdfMoneyHeader(', start);
    expect(start, greaterThan(0));
    expect(end, greaterThan(start));
    final block = main.substring(start, end);
    expect(block, contains('pw.Directionality('));
    expect(block, contains('textDirection:pw.TextDirection.ltr'));
    expect(block.indexOf('pdfCurrencyMark('), lessThan(block.indexOf('pw.Text(text,')));
    expect(main, contains("if(pdfCurrency=='SAR')return pw.Image(pdfRiyalIcon,"));
    expect(main, isNot(contains("if(!english&&pdfCurrency=='SAR')")));
  });

  test('M666 both Android build paths render SAR icon before signed widget text',
    () {
    final native = File('native/WaffraWidget.kt').readAsStringSync();
    expect(native, contains('setOf("ريال", "SAR")'));
    for (final path in <String>[
      '.github/workflows/android.yml',
      '.github/workflows/android-full-smoke.yml',
    ]) {
      final xmlSource = File(path).readAsStringSync();
      final row = xmlSource.indexOf('android:layoutDirection="ltr"');
      final mark = xmlSource.indexOf('android:id="@+id/widget_riyal_icon"', row);
      final balance = xmlSource.indexOf('android:id="@+id/widget_balance"', row);
      expect(row, greaterThan(0), reason: path);
      expect(mark, greaterThan(row), reason: path);
      expect(balance, greaterThan(mark), reason: path);
      expect(xmlSource, contains('android:textDirection="ltr"'));
    }
    final notice = File('native/WaffraAutoSmsNotifications.kt').readAsStringSync();
    expect(notice, contains('Paint().hasGlyph'));
    expect(notice, contains('val amountRun = '));
    expect(notice, isNot(contains(r'"$amount ر.س • "')));
  });
}
