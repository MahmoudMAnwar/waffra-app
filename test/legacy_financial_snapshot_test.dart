import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/legacy_financial_snapshot.dart';

void main() {
  const inspector = WaffraLegacySnapshotInspector();

  Map<String, Object?> base({
    List<Map<String, Object?>> entries = const [],
    List<Map<String, Object?>> categories = const [],
    List<Map<String, Object?>> goals = const [],
    List<Map<String, Object?>> recurring = const [],
  }) =>
      {
        'entries': jsonEncode(entries),
        'waffra_categories_v24': jsonEncode(categories),
        'waffra_goals_v24': jsonEncode(goals),
        'waffra_recurring_v24': jsonEncode(recurring),
        'waffra_challenges_v1': '[]',
        'waffra_deleted_categories_v1': '[]',
        'waffra_deleted_goals_v1': '[]',
        'waffra_deleted_recurring_v1': '[]',
        'waffra_recurring_postponed_v1': '{}',
        'waffra_learned_merchants_v1': '{}',
        'waffra_sms_hashes_v1': <String>[],
        'waffra_monthly_budget_v1': 1000.0,
        'waffra_monthly_budget_enabled_v1': true,
        'waffra_recurring_reminders_enabled_v1': false,
      };

  Map<String, Object?> entry(
    String id,
    num amount, {
    bool income = false,
    String? receiptPath,
  }) =>
      {
        'id': id,
        'title': 'مشتريات / Salary',
        'category': income ? 'راتب' : 'طعام',
        'amount': amount,
        'income': income,
        'date': '2026-10-20T22:30:00.000',
        'receiptPath': receiptPath,
      };

  test('empty data is safe to stage without modifying preferences', () {
    final input = base();
    final original = jsonEncode(input);
    final result = inspector.inspect(input);
    expect(result.canStage, isTrue);
    expect(result.counts['entries'], 0);
    expect(result.incomeMinor, 0);
    expect(result.expenseMinor, 0);
    expect(jsonEncode(input), original);
  });

  test('income and expense sums are exact integer halalas', () {
    final input = base(entries: [
      entry('one', 1200.25, income: true),
      entry('two', 15.99),
      entry('three', 0.01),
    ]);
    final result = inspector.inspect(input);
    expect(result.canStage, isTrue);
    expect(result.counts['entries'], 3);
    expect(result.incomeMinor, 120025);
    expect(result.expenseMinor, 1600);
  });

  test('multiple receipt references preserve cardinality', () {
    final result = inspector.inspect(base(entries: [
      entry('one', 2, receiptPath: jsonEncode(['/a.jpg', '/b.png'])),
      entry('two', 3, receiptPath: '/legacy.jpg'),
    ]));
    expect(result.canStage, isTrue);
    expect(result.receiptReferences, 3);
  });

  test('corrupt JSON blocks migration without losing raw source', () {
    final input = base()..['entries'] = '[{bad JSON';
    final before = input['entries'];
    final result = inspector.inspect(input);
    expect(result.canStage, isFalse);
    expect(result.issues.map((e) => e.code), contains('invalid_json'));
    expect(input['entries'], before);
  });

  test('duplicate legacy transaction IDs block automatic cutover', () {
    final result = inspector.inspect(base(entries: [
      entry('duplicate', 3),
      entry('duplicate', 7),
    ]));
    expect(result.canStage, isFalse);
    expect(result.issues.map((e) => e.code), contains('duplicate_id'));
  });

  test('non-cent amounts are rejected, never silently rounded', () {
    expect(WaffraLegacySnapshotInspector.amountToHalalas(0.001), isNull);
    expect(WaffraLegacySnapshotInspector.amountToHalalas(-1), isNull);
    expect(WaffraLegacySnapshotInspector.amountToHalalas(double.nan), isNull);
    expect(WaffraLegacySnapshotInspector.amountToHalalas(1.23), 123);
    final result = inspector.inspect(base(entries: [entry('bad', 3.333)]));
    expect(result.canStage, isFalse);
    expect(result.issues.map((e) => e.code), contains('invalid_amount'));
  });

  test('invalid transaction dates do not default to today', () {
    final bad = entry('bad', 1)..['date'] = 'not-a-date';
    final result = inspector.inspect(base(entries: [bad]));
    expect(result.canStage, isFalse);
    expect(result.issues.map((e) => e.code), contains('invalid_date'));
  });

  test('deleted goal snapshots and timestamps are validated', () {
    final input = base()
      ..['waffra_deleted_goals_v1'] = jsonEncode([
        {
          'goal': {'id': 'goal-1', 'name': 'سيارة', 'target': 5000, 'saved': 300},
          'deletedAt': '2026-10-19T12:00:00.000',
        }
      ]);
    final result = inspector.inspect(input);
    expect(result.canStage, isTrue);
    expect(result.counts['waffra_deleted_goals_v1'], 1);
  });

  test('invalid deleted timestamp blocks cutover', () {
    final input = base()
      ..['waffra_deleted_categories_v1'] = jsonEncode([
        {
          'category': {'id': 'c1', 'name': 'مطاعم'},
          'deletedAt': 'never',
        }
      ]);
    expect(inspector.inspect(input).issues.map((e) => e.code),
        contains('invalid_deleted_at'));
  });

  test('recurring due day is validated', () {
    final result = inspector.inspect(base(recurring: [
      {
        'id': 'rec-1',
        'title': 'إيجار',
        'category': 'سكن',
        'amount': 900,
        'income': false,
        'day': 32,
        'active': true,
        'startAt': '2026-10-01T00:00:00.000',
      }
    ]));
    expect(result.canStage, isFalse);
    expect(result.issues.map((e) => e.code), contains('invalid_due_day'));
  });

  test('diagnostics never contain private transaction titles or paths', () {
    final result = inspector.inspect(base(entries: [
      entry('id1', 2, receiptPath: '/private/photo.jpg'),
    ]));
    final output = jsonEncode(result.safeDiagnostics);
    expect(output, isNot(contains('مشتريات')));
    expect(output, isNot(contains('/private')));
  });

  test('missing source keys are distinguished from present empty', () {
    final result = inspector.inspect({'entries': '[]'});
    expect(result.counts['entries'], 0);
    expect(result.missingKeys, contains('waffra_goals_v24'));
    expect(result.missingKeys, isNot(contains('entries')));
  });
}
