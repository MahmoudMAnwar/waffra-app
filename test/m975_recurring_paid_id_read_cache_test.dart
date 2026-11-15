import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_recurring_policy.dart';

/// M975/#675: exact read-only settlement membership and due-date parity.
void main() {
  test('M975 10000 historical IDs equal original monthly scan for every due',
      () {
    final historical = List<String>.generate(10000, (i) => 'history-$i');
    final month = WaffraRecurringPolicy.dueDate(2026, 11, 5);
    for (var i = 0; i < 390; i += 13) {
      historical.add(WaffraRecurringPolicy.entryId('bill-$i', month));
    }
    historical.add(historical.last); // Legacy duplicate source ID.
    final indexed = Set<String>.unmodifiable(historical);
    final today = DateTime(2026, 11, 15);
    for (var i = 0; i < 390; i++) {
      final id = WaffraRecurringPolicy.entryId('bill-$i', month);
      final wasPaid = historical.any((entry) => entry == id);
      expect(indexed.contains(id), wasPaid, reason: id);
      final postponed = i % 17 == 0 ? DateTime(2026, 12, 10) : null;
      final original = WaffraRecurringPolicy.nextActionableDue(
        today: today, startAt: DateTime(2025, 4, 15), day: 5,
        currentMonthPaid: wasPaid, postponedUntil: postponed);
      final cached = WaffraRecurringPolicy.nextActionableDue(
        today: today, startAt: DateTime(2025, 4, 15), day: 5,
        currentMonthPaid: indexed.contains(id), postponedUntil: postponed);
      expect(cached, original, reason: id);
    }
    expect(historical.length, 10031);
    expect(indexed.length, historical.length - 1);
  });

  test('M975 accountless and unrelated old-month receipts cannot mark month paid',
      () {
    final monthId = WaffraRecurringPolicy.entryId(
        'rent', WaffraRecurringPolicy.dueDate(2026, 11, 5));
    final source = Set<String>.unmodifiable([
      'unassigned-history',
      WaffraRecurringPolicy.entryId(
          'rent', WaffraRecurringPolicy.dueDate(2024, 1, 5)),
      WaffraRecurringPolicy.entryId(
          'other', WaffraRecurringPolicy.dueDate(2026, 11, 5)),
    ]);
    expect(source.contains(monthId), isFalse);
    final due = WaffraRecurringPolicy.nextActionableDue(
      today: DateTime(2026, 11, 15), startAt: DateTime(2025, 1, 1),
      day: 5, currentMonthPaid: source.contains(monthId));
    expect(due, DateTime(2026, 11, 5));
  });

  test('M975 actual UI memoizes by object identity, never schedule text', () {
    final content = File('lib/waffra_home_goals_recurring_pages.part.dart')
        .readAsStringSync();
    expect(content, contains('Set<String>.unmodifiable(entries.map((e)=>e.id))'));
    expect(content, contains('Map<RecurringBill,DateTime>.identity()'));
    expect(content, contains('dueDates.putIfAbsent(r,'));
    expect(content, contains('nextRecurringDue(r,paidEntryIds:paidEntryIds)'));
    expect(content, contains('r.linkedGoalId==null?dueFor(r):r.startAt'));
    expect(content, contains('final due=goal==null?dueFor(r):r.startAt;'));
    expect(content, isNot(contains('final due=goal==null?nextRecurringDue(r)')));
  });

  test('M975 original due policy remains fallback with no finance writes', () {
    final code = File('lib/waffra_home_recurring_workflows.part.dart')
        .readAsStringSync();
    final first = code.indexOf(' DateTime nextRecurringDue(');
    final last = code.indexOf(' Future<void> _setRecurringActiveFromCard', first);
    expect(first, greaterThanOrEqualTo(0));
    expect(last, greaterThan(first));
    final body = code.substring(first, last);
    expect(body, contains('paidEntryIds?.contains(monthId)??'));
    expect(body, contains('entries.any((entry)=>entry.id==monthId)'));
    expect(body, contains('WaffraRecurringPolicy.nextActionableDue('));
    expect(body, contains('postponedUntil:DateTime.tryParse('));
    expect(body, isNot(contains('INSERT INTO')));
    expect(body, isNot(contains('DELETE FROM')));
    expect(body, isNot(contains('UPDATE fresh_finance')));
  });
}
