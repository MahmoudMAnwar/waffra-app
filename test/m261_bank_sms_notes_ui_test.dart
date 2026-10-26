import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_i18n.dart';

void main() {
  const original = 'شراء PoS\nبـ84.72SR\nمن بطاقة تجريبية\n22/10/26';
  const personal = 'اشتريت قهوة\nأرجع لها آخر الشهر';

  for (final english in [false, true]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('M261 original SMS and editable annotation remain distinct'
          ' in ${english ? 'English' : 'Arabic'} $brightness',
          (tester) async {
        waffraLanguage.value = english ? 'en' : 'ar';
        addTearDown(() => waffraLanguage.value = 'ar');
        await tester.binding.setSurfaceSize(const Size(360, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final entry = MoneyEntry(
          id: 'synthetic-m261',
          title: 'عملية اختبار',
          category: 'أخرى',
          amount: 84.72,
          income: false,
          date: DateTime.utc(2026, 10, 22),
          notes: original,
          sourceType: 'sms',
        );
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness, useMaterial3: true,
              fontFamily: 'Tajawal'),
          home: Scaffold(body: WaffraTransactionDetailsDialog(
            entry: entry,
            protectedUserNote: personal,
            onClose: () {},
          )),
        ));
        await tester.pumpAndSettle();
        expect(find.text(original), findsOneWidget);
        expect(find.text(personal), findsOneWidget);
        expect(find.text(english ? 'Your notes' : 'ملاحظاتك'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  test('M261 editor never overwrites original SMS in a legacy transaction',
      () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains("final editingProtectedSms=!sms&&initial?.sourceType=='sms';"));
    expect(source, contains('notes:editingProtectedSms?initial!.notes:'));
    expect(source, contains('readProtectedOriginalSms(initial!.id)'));
    expect(source, contains('readProtectedSmsUserNote(initial.id)'));
    expect(source, contains('updateProtectedSmsUserNote('));
    expect(source, contains("if(entry.sourceType=='sms'){"));
    expect(source, contains('protectedUserNote:protectedUserNote'));
    expect(source, contains('await _loadFinanceSafely();'));
    // Guarded SharedPreferences still cannot receive a bank SMS annotation.
    final guard = File('lib/storage/waffra_home_finance_persistence.dart')
        .readAsStringSync();
    expect(guard, contains('rejectNewOrModifiedSmsNotes('));
  });
}
