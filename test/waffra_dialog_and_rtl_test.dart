import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_i18n.dart';

void main() {
  setUp(() => waffraLanguage.value = 'ar');
  tearDown(() => waffraLanguage.value = 'ar');

  test('Dialog border remains visible in light and dark modes', () {
    final light = waffraDialogOutline(Brightness.light);
    final dark = waffraDialogOutline(Brightness.dark);

    expect(light.width, greaterThanOrEqualTo(1.0));
    expect(light.width, lessThanOrEqualTo(1.5));
    expect(dark.width, greaterThanOrEqualTo(1.0));
    expect(dark.width, lessThanOrEqualTo(1.5));
    expect(light.color.alpha, greaterThan(0));
    expect(dark.color.alpha, greaterThan(0));
    expect(light.color, isNot(dark.color));
  });

  testWidgets('Arabic transaction details have right-to-left alignment', (tester) async {
    final entry = MoneyEntry(
      id: 'rtl-test', title: 'شراء نقاط بيع - شراء PoS عبر:7678;مدى',
      category: 'تسوّق', amount: 74, income: false, date: DateTime(2026, 10, 20),
    );
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(side: waffraDialogOutline(Brightness.light)),
      )),
      home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () => showWaffraDialog<void>(
          context: context,
          builder: (dialogContext) => WaffraTransactionDetailsDialog(
            entry: entry, onClose: () => Navigator.pop(dialogContext),
          ),
        ),
        child: const Text('Open details'),
      ))),
    ));

    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();
    expect(find.text('تفاصيل المعاملة'), findsOneWidget);
    final text = tester.widget<WaffraText>(find.byWidgetPredicate(
      (w) => w is WaffraText && w.data == entry.title,
    ));
    expect(text.textDirection, TextDirection.rtl);
    expect(text.textAlign, TextAlign.start);
    final inside = find.descendant(
      of: find.byType(WaffraTransactionDetailsDialog),
      matching: find.byType(Directionality),
    );
    expect(inside, findsWidgets);
    expect(tester.widget<Directionality>(inside.first).textDirection, TextDirection.rtl);
    await tester.tap(find.text('إغلاق'));
    await tester.pumpAndSettle();
    expect(find.byType(WaffraTransactionDetailsDialog), findsNothing);
  });

  testWidgets('English transaction details use left-to-right alignment', (tester) async {
    waffraLanguage.value = 'en';
    final entry = MoneyEntry(
      id: 'ltr-test', title: 'Card purchase POS 7678',
      category: 'Shopping', amount: 74, income: false, date: DateTime(2026, 10, 20),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: WaffraTransactionDetailsDialog(
        entry: entry, onClose: () {},
      )),
    ));
    final text = tester.widget<WaffraText>(find.byWidgetPredicate(
      (w) => w is WaffraText && w.data == entry.title,
    ));
    expect(text.textDirection, TextDirection.ltr);
    expect(text.textAlign, TextAlign.start);
    expect(find.text('Transaction details'), findsOneWidget);
  });
}
