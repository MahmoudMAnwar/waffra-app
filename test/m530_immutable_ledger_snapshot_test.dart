import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart' show MoneyEntry;
import 'package:waffra/waffra_large_json_decode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('M530 large immutable ledger worker preserves exact JSON bytes and order',
      () async {
    final source = List<MoneyEntry>.generate(5000, (i) => MoneyEntry(
      id: 'finance-$i',
      title: 'Expense رقم $i',
      category: i.isEven ? 'مصروفات' : 'الدخل',
      amount: i + 0.25,
      income: i.isOdd,
      date: DateTime.utc(2026, 11, 1, 8, 30).add(Duration(minutes: i)),
      notes: 'original SMS source $i',
      personalNotes: 'user note $i',
      sourceType: i % 13 == 0 ? 'goal_due' : 'manual',
      merchantKey: 'merchant-$i',
      receiptPath: i % 10 == 0 ? '/local/receipt-$i.jpg' : null,
      budgetId: i % 3 == 0 ? 'budget-1' : null,
      goalWalletPaidMinor: i % 13 == 0 ? 125 : 0,
    ));
    final frozen = List<MoneyEntry>.unmodifiable(source);
    expect(frozen.length,
        greaterThan(WaffraLargeJsonDecode.encodeRowThreshold));
    final expected = jsonEncode(
        frozen.map((e) => e.toJson()).toList(growable: false));
    final actual = await compute(MoneyEntry.encodeFrozenSnapshot, frozen);
    expect(actual, expected);
    expect(jsonDecode(actual), jsonDecode(expected));
    expect((jsonDecode(actual) as List).first['id'], 'finance-0');
    expect((jsonDecode(actual) as List).last['id'], 'finance-4999');
    expect(actual, contains('goalWalletPaidMinor'));
    expect(actual, contains('budgetId'));
  });

  test('M530 immutable source snapshot remains fixed across later list changes',
      () async {
    final entries = <MoneyEntry>[
      MoneyEntry(
        id: 'first',
        title: 'Verified',
        category: 'salary',
        amount: 10,
        income: true,
        date: DateTime.utc(2026, 11, 1),
      ),
    ];
    final frozen = List<MoneyEntry>.unmodifiable(entries);
    entries.clear();
    entries.add(MoneyEntry(
      id: 'later',
      title: 'Later save',
      category: 'expense',
      amount: 25,
      income: false,
      date: DateTime.utc(2026, 11, 2),
    ));
    final encoded = await compute(MoneyEntry.encodeFrozenSnapshot, frozen);
    final output = jsonDecode(encoded) as List;
    expect(output.length, 1);
    expect(output.first['id'], 'first');
    expect(encoded, isNot(contains('later')));
  });

  test('M530 small histories keep original encoder and JSON format', () async {
    final small = List<MoneyEntry>.generate(7, (i) => MoneyEntry(
      id: 'small-$i',
      title: 'Small $i',
      category: 'category',
      amount: i + 1.5,
      income: i.isEven,
      date: DateTime.utc(2026, 11, 1),
    ));
    final rows = small.map((e) => e.toJson()).toList(growable: false);
    final original = await WaffraLargeJsonDecode.encodeRecords(rows);
    final worker = await compute(
        MoneyEntry.encodeFrozenSnapshot, List<MoneyEntry>.unmodifiable(small));
    expect(worker, original);
  });
}
