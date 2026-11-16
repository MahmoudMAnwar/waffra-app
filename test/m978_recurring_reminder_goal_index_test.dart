import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// M978 / #681: source-only reminder filter equivalence on large history.
void main() {
  test('M978 dated goal set equals former any() predicate for 10k goals',
      () {
    final goals = List<({String id, bool dated})>.generate(
      10000, (i) => (id: 'goal-${i ~/ 2}', dated: i % 7 != 0));
    goals.add((id: 'goal-duplicate', dated: false));
    goals.add((id: 'goal-duplicate', dated: true));
    final index = <String>{
      for (final goal in goals)
        if (goal.dated) goal.id,
    };
    final ids = <String?>[
      null,
      'goal-duplicate',
      'unknown',
      'goal-0',
      'goal-1',
      ...List<String?>.generate(1000, (i) => 'goal-${i * 5}'),
    ];
    for (final id in ids) {
      final previous = id == null ||
        goals.any((g) => g.id == id && g.dated);
      final indexed = id == null || index.contains(id);
      expect(indexed, previous, reason: 'linked goal $id');
    }
    expect(index.contains('goal-duplicate'), isTrue);
    expect(index.contains('unknown'), isFalse);
    expect(goals.length, 10002);
  });

  test('M978 disabled/undated/missing linked goals preserve schedule policy',
      () {
    final goals = <({String id, bool dated})>[
      (id: 'valid', dated: true),
      (id: 'expired', dated: false),
      (id: 'valid', dated: false),
    ];
    final scheduled = <({String id, bool active, bool categoryAllowed,
        String? linkedGoalId})>[
      (id: 'standalone', active: true, categoryAllowed: true,
        linkedGoalId: null),
      (id: 'valid-goal', active: true, categoryAllowed: true,
        linkedGoalId: 'valid'),
      (id: 'undated-goal', active: true, categoryAllowed: true,
        linkedGoalId: 'expired'),
      (id: 'unknown-goal', active: true, categoryAllowed: true,
        linkedGoalId: 'missing'),
      (id: 'inactive', active: false, categoryAllowed: true,
        linkedGoalId: 'valid'),
      (id: 'bad-category', active: true, categoryAllowed: false,
        linkedGoalId: 'valid'),
    ];
    final index = <String>{
      for(final goal in goals) if(goal.dated) goal.id,
    };
    final before = scheduled.where((r) =>
      r.active && r.categoryAllowed && (r.linkedGoalId == null ||
        goals.any((g) => g.id == r.linkedGoalId && g.dated)))
        .map((r) => r.id).toList();
    final after = scheduled.where((r) =>
      r.active && r.categoryAllowed && (r.linkedGoalId == null ||
        index.contains(r.linkedGoalId))).map((r) => r.id).toList();
    expect(after, before);
    expect(after, ['standalone', 'valid-goal']);
  });

  test('M978 actual reminder route keeps exact app schedule and safe guard',
      () {
    final file = File('lib/waffra_home_finance_persistence_due.part.dart')
        .readAsStringSync();
    final start = file.indexOf(' Future<void> syncRecurringReminders()async {');
    final end = file.indexOf(' Future<void> toggleRecurringReminders(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final actual = file.substring(start, end);
    expect(actual, contains('if(!recurringRemindersEnabled)return;'));
    expect(actual, contains('final datedGoalIds=<String>{'));
    expect(actual, contains('if(goal.dueDate!=null)goal.id,'));
    expect(actual, contains('datedGoalIds.contains(r.linkedGoalId)'));
    expect(actual, contains('r.linkedGoalId==null||'));
    expect(actual, contains('waffraCategoryNameAvailableForPosting('));
    // M1013: a postponed goal due must use the effective date, and a
    // confirmed settlement cannot keep scheduling pre-due notifications.
    expect(actual, contains('paidGoalDueKeys.contains(WaffraRecurringPolicy.entryId('));
    expect(actual, contains('oneTimeDueAt:r.linkedGoalId==null?null:'));
    expect(actual, contains('DateTime.tryParse(recurringPostponed['));
    expect(actual, contains('WaffraRecurringPolicy.entryId(r.id,r.startAt)'));
    expect(actual, contains('WaffraReminders.schedule('));
    expect(actual, isNot(contains('goals.any(')));
    expect(actual, isNot(contains('INSERT INTO')));
    expect(actual, isNot(contains('entries.insert(')));
  });
}
