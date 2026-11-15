import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart' show WaffraHomeCardIdIndex;

/// M974/#673: read-only Home card indexes, no archive/phone or money writes.
void main() {
  test('M974 source rows and duplicate IDs keep original positional order', () {
    final rows = <({String id, int value})>[
      (id: 'a', value: 1),
      (id: 'b', value: 2),
      (id: 'a', value: 3),
    ];
    final indexed = WaffraHomeCardIdIndex<({String id, int value})>(
      rows, (r) => r.id);
    expect(indexed.matches('a').map((r) => r.value), [1, 3]);
    expect(indexed.matches('b').single.value, 2);
    expect(indexed.matches('missing'), isEmpty);
    expect(indexed.matches(null), isEmpty);
    expect(indexed.matches('a'), same(indexed.matches('a')));
    expect(() => indexed.matches('a').clear(), throwsUnsupportedError);
    rows.clear();
    expect(indexed.matches('a').length, 2);
  });

  test('M974 verified bank lookup retains exactly-one active-account policy', () {
    final accounts = <({String id, String name, bool archived})>[
      (id: 'current', name: 'Primary', archived: false),
      (id: 'archived', name: 'Old', archived: true),
      (id: 'duplicate', name: 'First', archived: false),
      (id: 'duplicate', name: 'Second', archived: false),
    ];
    final index = WaffraHomeCardIdIndex<
        ({String id, String name, bool archived})>(
      accounts.where((a) => !a.archived), (a) => a.id);
    expect(index.matches('current').single.name, 'Primary');
    expect(index.matches('archived'), isEmpty);
    expect(index.matches('duplicate').length, 2);
    expect(index.matches(null), isEmpty);
  });

  test('M974 10000 historical entries preserve source type and paid uniqueness',
      () {
    final rows = List<Map<String, Object?>>.generate(10000, (i) =>
      <String, Object?>{
        'id': 'entry-${i ~/ 2}',
        'sourceType': i.isEven ? 'manual' : 'goal_due',
        'amountMinor': i,
      }, growable: true);
    rows.addAll(<Map<String, Object?>>[
      {'id': 'duplicate-paid', 'sourceType': 'goal_due', 'amountMinor': 200},
      {'id': 'duplicate-paid', 'sourceType': 'goal_due', 'amountMinor': 300},
    ]);
    final index = WaffraHomeCardIdIndex<Map<String, Object?>>(
      rows.where((r) => r['sourceType'] == 'goal_due'),
      (r) => r['id'] as String?);
    expect(index.matches('entry-100').length, 1);
    expect(index.matches('entry-100').single['amountMinor'], 201);
    expect(index.matches('duplicate-paid').length, 2);
    // Original card condition requires exactly one settlement receipt.
    expect(index.matches('duplicate-paid').length == 1, isFalse);
    expect(index.matches('unknown'), isEmpty);
    expect(rows.length, 10002);
    expect(index.matches('entry-100'), same(index.matches('entry-100')));
    expect(() => index.matches('duplicate-paid').removeAt(0),
        throwsUnsupportedError);
  });

  test('M974 goal duplicate still fails closed instead of selecting first', () {
    final goals = [
      (id: 'goal-a', name: 'First'),
      (id: 'goal-a', name: 'Second'),
    ];
    final index = WaffraHomeCardIdIndex<({String id, String name})>(
      goals, (g) => g.id);
    expect(index.matches('goal-a').length, 2);
    expect(() => index.matches('goal-a').single, throwsStateError);
  });

  test('M974 actual Goal/Due UI uses indexes and unchanged money conditions',
      () {
    final source = File('lib/waffra_home_goals_recurring_pages.part.dart')
        .readAsStringSync();
    expect(source, contains('final linkedGoalById=WaffraHomeCardIdIndex<SavingGoal>'));
    expect(source, contains('final paidGoalDueById=WaffraHomeCardIdIndex<MoneyEntry>'));
    expect(source, contains("entries.where((e)=>e.sourceType=='goal_due')"));
    expect(source, contains('final linked=linkedGoalById.matches(r.linkedGoalId);'));
    expect(source, contains('final paid=paidGoalDueById.matches(settledId);'));
    expect(source, contains('final goal=linked.isEmpty?null:linked.single;'));
    expect(source, contains('paid.length==1?paid.single:null'));
    expect(source, contains('activeAccountById.matches(g.accountId)'));
    expect(source, contains('activeAccountById.matches(r.accountId)'));
    expect(source, isNot(contains('entries.where((e)=>e.id==settledId')));
    expect(source, isNot(contains('INSERT INTO')));
    expect(source, isNot(contains('UPDATE fresh_finance')));
    expect(source, isNot(contains('DELETE FROM')));
  });
}
