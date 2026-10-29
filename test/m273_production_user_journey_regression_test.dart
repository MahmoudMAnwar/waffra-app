import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_display_currency.dart';
import 'package:waffra/waffra_i18n.dart';
import 'package:waffra/waffra_recurring_policy.dart';
import 'package:waffra/waffra_smart_features.dart';

/// M273: synthetic, deterministic user journeys. No real financial PII,
/// bank access, live FX calls, or production finance database modifications.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    waffraLanguage.value = 'ar';
    hideWaffraAmounts.value = false;
    WaffraDisplayCurrency.active.value =
        WaffraDisplayCurrency.displaySelection('SAR');
  });
  tearDown(() {
    waffraLanguage.value = 'ar';
    hideWaffraAmounts.value = false;
    WaffraDisplayCurrency.active.value =
        WaffraDisplayCurrency.displaySelection('SAR');
  });

  test('P0: paste preview differentiates new, duplicate and already saved SMS',
      () {
    const first = 'شراء PoS\nبـ84.72SR\nمن 1111\n16/10/26 00:43';
    const second = 'شراء PoS\nبـ15.28SR\nمن 1111\n16/10/26 00:44';
    final batch = [first, first, second].join('\n\n');
    final initial = waffraSummarizeBankPaste(batch, <String>{});
    expect(initial.detected, 3);
    expect(initial.fresh, 2);
    expect(initial.duplicates, 1);
    expect(initial.excluded, 0);

    final reimport =
        waffraSummarizeBankPaste(batch, <String>{bankSmsHash(first)});
    expect(reimport.detected, 3);
    expect(reimport.fresh, 1);
    expect(reimport.duplicates, 2);
    expect(reimport.excluded, 0);
    expect(bankSmsHash(first.replaceAll('\n', '  ')), bankSmsHash(first));
  });

  test('P0: OTP and failed notices are not converted to expense records', () {
    const otp = 'OTP 867530\nDo not share this code\nAmount: SAR 999';
    const confirmed = 'شراء PoS\nبـ39.25SR\nمن 1111\n16/10/26 00:43';
    final summary =
        waffraSummarizeBankPaste([otp, confirmed].join('\n'), <String>{});
    expect(BankParser.parse(otp).amount, isNull);
    expect(summary.detected, 1);
    expect(summary.fresh, 1);
    expect(summary.excluded, 1);
  });

  test('P0: a 100-message synthetic batch splits without losing records', () {
    final input = List.generate(100, (i) {
      final amount = i + 1;
      return 'شراء PoS\nبـ'+amount.toString()+'.00 SR\n'
          'من '+i.toString().padLeft(4, '0')+'\n16/10/26 00:43';
    }).join('\n');
    final parts = splitBankMessages(input);
    expect(parts, hasLength(100));
    final summary = waffraSummarizeBankPaste(input, <String>{});
    expect(summary.detected, 100);
    expect(summary.fresh, 100);
    expect(summary.duplicates, 0);
    // The 101st message must be refused at the confirmation boundary,
    // not silently truncated to 100 during import.
    final savePath = File('lib/main.dart').readAsStringSync();
    expect(savePath, contains('if(found.length>100)'));
  });

  test('P0: incoming credit and credit-card expense keep opposite directions',
      () {
    const received =
        'Credit Transfer\nAmount: SAR 520.10\nBalance: SAR 2,000.00';
    const purchase =
        'Credit Card Purchase\nAmount: SAR 37.25\nBalance: SAR 1,962.75';
    final income = BankParser.parse(received);
    final expense = BankParser.parse(purchase);
    expect(income.income, isTrue);
    expect(income.amount, 520.10);
    expect(expense.income, isFalse);
    expect(expense.amount, 37.25);
  });

  test('P0: bank dates reject impossible and invalid time values', () {
    expect(bankSmsDate('Card Purchase\n2028-02-29 23:59'),
        DateTime(2028, 2, 29, 23, 59));
    expect(bankSmsDate('Card Purchase\n2027-02-29 23:59'), isNull);
    expect(bankSmsDate('Transfer Received\n2026-10-17 24:02'), isNull);
    expect(bankSmsDate('شراء PoS\n16/10/26 00:43'),
        DateTime(2026, 10, 16, 0, 43));
  });

  test('P0: transaction JSON round trip preserves notes and all receipts', () {
    const original = 'شراء من متجر تجريبي\nPOS 84.72 SR\nملاحظة بالعربية';
    final attachments = [
      'receipt one.jpeg',
      'إيصال ٢.png',
      'attachment_3.webp',
    ];
    final entry = MoneyEntry(
      id: 'synthetic-1',
      title: 'شراء تجربة',
      category: 'تسوّق / أخرى',
      amount: 84.72,
      income: false,
      date: DateTime(2026, 10, 27, 12, 30),
      notes: original,
      receiptPath: waffraEncodeReceipts(attachments),
      sourceType: 'sms',
      merchantKey: 'demo-merchant',
    );
    final restored = MoneyEntry.fromJson(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(entry.toJson()))));
    expect(restored.id, entry.id);
    expect(restored.title, entry.title);
    expect(restored.notes, original);
    expect(restored.sourceType, 'sms');
    expect(restored.merchantKey, 'demo-merchant');
    expect(restored.amount, 84.72);
    expect(restored.income, isFalse);
    expect(restored.date, entry.date);
    expect(waffraReceiptPaths(restored.receiptPath), attachments);
  });

  test('P0: editing other fields preserves unchanged long legacy descriptions',
      () {
    final oldBankText = List.filled(4100, 'ر').join();
    expect(waffraTransactionTitleAllowed(
        oldBankText, oldTitle: oldBankText), isTrue);
    expect(waffraTransactionTitleAllowed(
        oldBankText + '!', oldTitle: oldBankText), isFalse);
    expect(waffraTransactionNotesAllowed(
        oldBankText, oldNotes: oldBankText), isTrue);
    expect(waffraTransactionNotesAllowed(
        oldBankText + '!', oldNotes: oldBankText), isFalse);
    expect(waffraTransactionNotesAllowed('س'.padRight(2000, 'س')), isTrue);
    expect(waffraTransactionNotesAllowed('س'.padRight(2001, 'س')), isFalse);
  });

  test('P0: Arabic, English and country changes do not rewrite ledger numbers',
      () {
    const storedAmount = 1234.50;
    final entry = MoneyEntry(
      id: 'finance-1',
      title: 'تجربة',
      category: 'أخرى',
      amount: storedAmount,
      income: true,
      date: DateTime(2026, 10, 27),
    );
    expect(WaffraDisplayCurrency.money(
        entry.amount, english: false), '1,234.50 ريال');
    waffraLanguage.value = 'en';
    expect(WaffraDisplayCurrency.money(
        entry.amount, english: true), '1,234.50 SAR');
    for (final currency in ['EGP', 'USD', 'AED', 'SAR']) {
      WaffraDisplayCurrency.active.value =
          WaffraDisplayCurrency.displaySelection(currency);
      expect(WaffraDisplayCurrency.amount(entry.amount), '1,234.50');
      expect(WaffraDisplayCurrency.toLedgerSar(entry.amount), storedAmount);
      expect(entry.amount, storedAmount);
      expect(WaffraDisplayCurrency.money(entry.amount, english: true),
          '1,234.50 ' + currency);
    }
  });

  test('P0: small income and expense entries yield exact halala totals', () {
    final income = [1000.25, 0.10, 0.20];
    final expense = [84.72, 15.28];
    expect(WaffraRecurringPolicy.netHalalas(income, expense), 90055);
    final entries = <WaffraSmartEntry>[
      for (var i = 0; i < income.length; i++)
        WaffraSmartEntry(id: 'income'+i.toString(), title: 'دخل',
            category: 'دخل', amount: income[i], income: true,
            date: DateTime(2026, 10, 27)),
      for (var i = 0; i < expense.length; i++)
        WaffraSmartEntry(id: 'expense'+i.toString(), title: 'مصروف',
            category: 'مصروف', amount: expense[i], income: false,
            date: DateTime(2026, 10, 27)),
    ];
    expect((waffraSmartBalance(entries) * 100).round(), 90055);
  });

  test('P1: leap-year payday safely advances after its calendar date', () {
    expect(waffraNextPayday(DateTime(2028, 2, 28), 31),
        DateTime(2028, 2, 29));
    expect(waffraNextPayday(DateTime(2028, 2, 29), 31),
        DateTime(2028, 3, 31));
    expect(waffraNextPayday(DateTime(2027, 2, 27), 31),
        DateTime(2027, 2, 28));
  });

  test('P1: recurring estimates clamp day 31 and never count income', () {
    final recurring = [
      const WaffraSmartRecurring('rent', 100, 31, false),
      const WaffraSmartRecurring('salary', 1000, 31, true),
    ];
    expect(waffraProjectedRecurringOutflows(
        DateTime(2026, 10, 30), DateTime(2026, 12, 1), recurring), 200);
    expect(WaffraRecurringPolicy.dueDate(2028, 2, 31),
        DateTime(2028, 2, 29));
    final due = DateTime(2026, 11, 30);
    expect(WaffraRecurringPolicy.isOutstanding(
        due: due, today: due, startAt: DateTime(2026, 10, 1),
        alreadyPaid: true), isFalse);
  });

  test('P1: suspicious-duplicate detection ignores incomes and old charges',
      () {
    WaffraSmartEntry record(String id, String title, double value,
            DateTime at, bool income) =>
        WaffraSmartEntry(
            id: id, title: title, category: 'Demo', amount: value,
            income: income, date: at);
    final values = [
      record('purchase-1', 'Coffee', 15, DateTime(2026, 10, 1), false),
      record('purchase-2', ' coffee ', 15, DateTime(2026, 10, 2), false),
      record('purchase-3', 'Coffee', 15, DateTime(2026, 10, 8), false),
      record('income-1', 'Coffee', 15, DateTime(2026, 10, 2), true),
    ];
    expect(
        waffraPotentialDuplicates(values).map((e) => e.id),
        orderedEquals(['purchase-2']));
  });

  test('P1: category outflow window excludes income and end-exclusive date',
      () {
    final records = [
      WaffraSmartEntry(id: 'a', title: 'A', category: 'مطاعم',
          amount: 25, income: false, date: DateTime(2026, 10, 1)),
      WaffraSmartEntry(id: 'b', title: 'B', category: 'مطاعم',
          amount: 30, income: false, date: DateTime(2026, 11, 1)),
      WaffraSmartEntry(id: 'c', title: 'C', category: 'مطاعم',
          amount: 100, income: true, date: DateTime(2026, 10, 12)),
      WaffraSmartEntry(id: 'd', title: 'D', category: 'سفر',
          amount: 20, income: false, date: DateTime(2026, 9, 30)),
    ];
    expect(
      waffraCategoryOutflows(records,
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 11, 1)),
      {'مطاعم': 25.0},
    );
  });

  testWidgets('P1: hidden balance never leaks the original amount or icon',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: RiyalAmount(1234.50)),
    ));
    expect(find.byType(Image), findsOneWidget);
    hideWaffraAmounts.value = true;
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.textContaining('***'), findsWidgets);
    expect(find.textContaining('1,234.50'), findsNothing);
    hideWaffraAmounts.value = false;
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
