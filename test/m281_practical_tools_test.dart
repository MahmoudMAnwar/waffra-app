import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/diagnostics/waffra_private_release_diagnostics.dart';
import 'package:waffra/waffra_practical_ledger_engine.dart';
import 'package:waffra/waffra_practical_tools_page.dart';

void main() {
  final oct = DateTime(2026, 10, 27);
  WaffraPracticalEntry entry(String id, {
    String title = 'Groceries', String category = 'Food',
    double amount = 12.30, bool income = false,
    DateTime? date, String notes = '', bool receipt = false,
  }) => WaffraPracticalEntry(
    id: id, title: title, category: category,
    amount: amount, income: income, date: date ?? oct,
    notes: notes, hasAttachment: receipt,
  );

  test('M281 data health flags possible duplicates without deleting records', () {
    final data = [
      entry('tx-1'), entry('tx-2'),
      entry('tx-1', title: 'Another', category: ''),
      entry('bad', amount: double.nan),
    ];
    final issues = WaffraDataHealth.inspect(data);
    expect(issues.map((i) => i.kind), containsAll([
      WaffraHealthIssueKind.possibleDuplicate,
      WaffraHealthIssueKind.duplicateId,
      WaffraHealthIssueKind.missingCategory,
      WaffraHealthIssueKind.invalidAmount,
    ]));
    expect(data.length, 4);
    expect(data[0].title, 'Groceries');
  });

  test('M281 advanced filters respect case, range, date, direction and attachments', () {
    final data = [
      entry('food', title: 'Coffee Shop', notes: 'Synthetic memo', receipt: true),
      entry('salary', title: 'SALARY', category: 'Income',
        income: true, amount: 5000),
      entry('old', title: 'Coffee Shop', date: DateTime(2025, 1, 1)),
    ];
    expect(WaffraLedgerSearch.find(data, query: 'COFFEE').length, 2);
    expect(WaffraLedgerSearch.find(data, query: 'synthetic').single.id, 'food');
    expect(WaffraLedgerSearch.find(data, income: true).single.id, 'salary');
    expect(WaffraLedgerSearch.find(data, attachment: true).single.id, 'food');
    expect(WaffraLedgerSearch.find(data, minimum: 1000).single.id, 'salary');
    expect(WaffraLedgerSearch.find(data, start: DateTime(2026, 10, 27),
      end: DateTime(2026, 10, 27)).length, 2);
    expect(() => WaffraLedgerSearch.find(data,
      minimum: 200, maximum: 10), throwsArgumentError);
  });

  test('M281 monthly close totals are exact integer halalas, no ledger mutation', () {
    final rows = [
      entry('pay', income: true, amount: 3100.10),
      entry('expense', amount: 50.05),
      entry('year-boundary', date: DateTime(2026, 11, 1), amount: 99999),
    ];
    final preview = WaffraMonthlyClose.preview(rows,
      year: 2026, month: 10, openingMinor: 5000);
    expect(preview.transactionCount, 2);
    expect(preview.incomeMinor, 310010);
    expect(preview.expenseMinor, 5005);
    expect(preview.expectedCloseMinor, 310005);
    expect(preview.differenceMinor(310105), 100);
    expect(rows.length, 3);
  });

  test('M281 corrupted amounts block closing rather than misstate balance', () {
    expect(() => WaffraMonthlyClose.preview([
      entry('invalid', amount: 1.005),
    ], year: 2026, month: 10, openingMinor: 0), throwsStateError);
    expect(() => WaffraMonthlyClose.preview([],
      year: 2026, month: 13, openingMinor: 0), throwsArgumentError);
  });

  test('M281 receipt review requires valid merchant and halala precision', () {
    WaffraReceiptReviewDraft draft(String merchant, double amount) =>
      WaffraReceiptReviewDraft(merchant: merchant, amount: amount, date: oct);
    expect(draft('Local merchant', 25.15).isValid, isTrue);
    expect(draft('', 25.15).isValid, isFalse);
    expect(draft('Local merchant', 25.155).isValid, isFalse);
    expect(draft('Local merchant', double.nan).isValid, isFalse);
    expect(draft('Local merchant', -1).isValid, isFalse);
  });

  test('M281 privacy diagnostics allowlist cannot include raw financial data', () {
    final tags = WaffraSafeDiagnosticCode.values
      .map((c) => WaffraSafeDiagnosticEvent(c).safeTag).toList();
    expect(tags, isNotEmpty);
    expect(tags.every((tag) => tag.startsWith('waffra_')), isTrue);
    for (final tag in tags) {
      for (final secret in ['bank', 'rawSms', 'amount', 'phone', 'receiptPath']) {
        expect(tag.toLowerCase(), isNot(contains(secret.toLowerCase())));
      }
    }
  });

  testWidgets('M281 all five tools are reachable with a verified read-only list',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: WaffraPracticalToolsPage(
      english: true, entries: [entry('first')],
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('m281-health-tile')), findsOneWidget);
    expect(find.byKey(const Key('m281-search-tile')), findsOneWidget);
    expect(find.byKey(const Key('m281-receipt-tile')), findsOneWidget);
    expect(find.byKey(const Key('m281-month-tile')), findsOneWidget);
    expect(find.byKey(const Key('m281-diagnostics-tile')), findsOneWidget);
    await tester.tap(find.text('Data health center'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('m281-health-count')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('M281 search is interactive without changing supplied entries',
      (tester) async {
    final rows = [entry('coffee', title: 'Coffee QA'),
      entry('salary', title: 'Salary QA', income: true)];
    await tester.pumpWidget(MaterialApp(home: WaffraPracticalToolsPage(
      english: true, entries: rows,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advanced financial search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('m281-search-query')), 'coffee');
    await tester.pumpAndSettle();
    expect(find.text('Results: 1'), findsOneWidget);
    expect(rows.length, 2);
    expect(rows.last.title, 'Salary QA');
  });
}
