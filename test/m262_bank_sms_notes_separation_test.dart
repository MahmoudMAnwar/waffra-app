import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_i18n.dart';

void main() {
  const original = 'شراء عبر نقاط بيع\nمن: بنك تجريبي\n'
      'بـ84.72 ريال\nالوقت: 10:35\nمرجع: TEST-123\n'
      'البيانات التجريبية لا تحتوي على حساب حقيقي';

  MoneyEntry sms({required String notes}) => MoneyEntry(
    id: 'encrypted-sms-fixture-1',
    title: 'شراء - متجر تجريبي',
    category: 'تسوق',
    amount: 84.72,
    income: false,
    date: DateTime(2026, 10, 26),
    sourceType: 'sms',
    notes: notes,
  );

  Widget details(MoneyEntry entry, {String? bankSms = original}) =>
      MaterialApp(
        home: Scaffold(
          body: WaffraTransactionDetailsDialog(
            entry: entry,
            protectedOriginalSms: bankSms,
            onClose: () {},
          ),
        ),
      );

  testWidgets('edited personal notes never hide the original encrypted SMS',
      (tester) async {
    waffraLanguage.value = 'ar';
    await tester.pumpWidget(details(sms(notes: '')));
    expect(find.text('لا توجد ملاحظات'), findsWidgets);
    final bank = find.byKey(
      const Key('waffra-transaction-protected-bank-sms'),
    );
    expect(bank, findsOneWidget);
    expect(tester.widget<SelectableText>(bank).data, original);

    // Simulates a persisted transaction edit and a new details open. The
    // protected original always stays independent of the notes attribute.
    await tester.pumpWidget(details(sms(notes: 'قسّطت مبلغ الشراء')));
    final personal = find.byKey(
      const Key('waffra-transaction-personal-notes'),
    );
    expect(tester.widget<SelectableText>(personal).data,
        'قسّطت مبلغ الشراء');
    expect(tester.widget<SelectableText>(bank).data, original);
    expect(find.text('تفاصيل الرسالة البنكية الأصلية (مشفّرة)'),
        findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vault failure is explicit and does not display fake SMS',
      (tester) async {
    waffraLanguage.value = 'ar';
    await tester.pumpWidget(details(
      sms(notes: 'ملاحظة منفصلة'),
      bankSms: null,
    ));
    expect(find.text('ملاحظة منفصلة'), findsWidgets);
    expect(find.text(
      'الرسالة البنكية الأصلية غير متاحة من التخزين المشفّر.',
    ), findsWidgets);
    expect(find.byKey(
      const Key('waffra-transaction-protected-bank-sms'),
    ), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('bank SMS details always read from vault regardless of notes content',
      () {
    final home = File('lib/main.dart').readAsStringSync();
    final start = home.indexOf('Future<void> transactionDetails(MoneyEntry entry)');
    final end = home.indexOf('\n Widget tile(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final method = home.substring(start, end);
    expect(method, contains("if(entry.sourceType=='sms'){"));
    expect(method, contains('readProtectedOriginalSms(entry.id)'));
    expect(method, contains('protectedOriginalSms:originalBankSms'));
    expect(method, isNot(contains('entry.notes.isEmpty')));
    expect(method, isNot(contains("...'notes':original")));
    expect(home, contains('notes:sms?message.text:notes.text'));
    expect(home, isNot(contains('if(sms)notes.text=text;')));
  });
}
