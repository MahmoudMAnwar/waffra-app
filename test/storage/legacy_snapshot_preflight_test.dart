import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/legacy_snapshot_preflight.dart';

void main() {
  Map<String, Object?> snapshot({
    String entries = '[]',
    String categories = '[]',
    String goals = '[]',
  }) =>
      {
        'entries': entries,
        'waffra_categories_v24': categories,
        'waffra_goals_v24': goals,
        'waffra_recurring_v24': '[]',
        'waffra_challenges_v1': '[]',
        'waffra_deleted_categories_v1': '[]',
        'waffra_deleted_goals_v1': '[]',
        'waffra_deleted_recurring_v1': '[]',
        'waffra_recurring_postponed_v1': '{}',
        'waffra_learned_merchants_v1': '{}',
        'waffra_sms_hashes_v1': <String>[],
        'waffra_monthly_budget_v1': 0.0,
        'waffra_monthly_budget_enabled_v1': false,
        'waffra_recurring_reminders_enabled_v1': false,
      };

  Map<String, Object?> entry(String id, {num amount = 42.50}) => {
        'id': id,
        'title': 'قهوة',
        'category': 'مطاعم',
        'amount': amount,
        'income': false,
        'date': '2026-10-21T02:15:00',
        'receiptPath': jsonEncode(['/receipts/one.jpg', '/receipts/two.png']),
      };

  test('valid financial snapshot is eligible for staging, never cutover', () {
    final input = snapshot(
      entries: jsonEncode([entry('tx-1'), entry('tx-2')]),
      goals: jsonEncode([
        {'id': 'g-1', 'name': 'سيارة', 'target': 12000.0, 'saved': 500.0}
      ]),
    );
    final result = WaffraLegacyPreflight.inspect(input);
    expect(result.canStage, isTrue);
    expect(result.itemCounts['entries'], 2);
    expect(result.itemCounts['waffra_goals_v24'], 1);
    expect(result.sourceSha256.length, 64);
    expect(input['entries'], contains('قهوة')); // No mutation.
  });

  test('checksum is deterministic, independent of source map insertion order', () {
    final first = snapshot(entries: jsonEncode([entry('tx-1')]));
    final reversed = Map<String, Object?>.fromEntries(first.entries.toList().reversed);
    expect(WaffraLegacyPreflight.inspect(first).sourceSha256,
        WaffraLegacyPreflight.inspect(reversed).sourceSha256);
  });

  test('checksum changes on financial change and absent versus empty', () {
    final original = snapshot();
    final changed = snapshot(entries: jsonEncode([entry('tx-1')]));
    final missing = snapshot()..remove('entries');
    expect(WaffraLegacyPreflight.inspect(original).sourceSha256,
        isNot(WaffraLegacyPreflight.inspect(changed).sourceSha256));
    expect(WaffraLegacyPreflight.inspect(original).sourceSha256,
        isNot(WaffraLegacyPreflight.inspect(missing).sourceSha256));
  });

  test('duplicate transaction IDs block staging, never collapse rows', () {
    final result = WaffraLegacyPreflight.inspect(
        snapshot(entries: jsonEncode([entry('dup'), entry('dup')])));
    expect(result.canStage, isFalse);
    expect(result.issues.map((e) => e.code), contains('duplicate_id'));
    expect(result.itemCounts['entries'], 2);
  });

  test('invalid dates do not default to current date', () {
    final broken = entry('tx-1')..['date'] = 'not-a-date';
    final result = WaffraLegacyPreflight.inspect(
        snapshot(entries: jsonEncode([broken])));
    expect(result.canStage, isFalse);
    expect(result.issues.map((e) => e.code), contains('invalid_date'));
  });

  test('non-cent precision is rejected instead of silently rounded', () {
    final result = WaffraLegacyPreflight.inspect(
        snapshot(entries: jsonEncode([entry('tx-1', amount: 2.005)])));
    expect(result.canStage, isFalse);
    expect(result.issues.map((e) => e.code), contains('invalid_amount'));
    expect(WaffraLegacyPreflight.canRepresentHalalas(0.1), isTrue);
    expect(WaffraLegacyPreflight.canRepresentHalalas(2.005), isFalse);
  });

  test('corrupt JSON blocks staging and does not crash', () {
    final result = WaffraLegacyPreflight.inspect(snapshot(entries: '[{'));
    expect(result.canStage, isFalse);
    expect(result.issues.single.code, 'invalid_json');
  });

  test('missing receipt files are not checked or deleted by preflight', () {
    final result = WaffraLegacyPreflight.inspect(
        snapshot(entries: jsonEncode([entry('tx-1')])));
    expect(result.canStage, isTrue);
  });

  test('malformed receipt array is detected without touching files', () {
    final broken = entry('tx-1')..['receiptPath'] = '[42]';
    final result = WaffraLegacyPreflight.inspect(
        snapshot(entries: jsonEncode([broken])));
    expect(result.canStage, isFalse);
    expect(result.issues.map((e) => e.code), contains('invalid_receipt_list'));
  });

  test('soft-deleted item must retain its original payload and timestamp', () {
    final input = snapshot()
      ..['waffra_deleted_goals_v1'] = jsonEncode([
        {'deletedAt': '2026-10-21T02:00:00', 'goal': {'id': 'goal-1', 'name': 'سفر', 'target': 100.0, 'saved': 50.0}},
        {'deletedAt': 'bad', 'goal': {'id': 'goal-2', 'name': 'سيارة', 'target': 100.0, 'saved': 50.0}},
      ]);
    final result = WaffraLegacyPreflight.inspect(input);
    expect(result.canStage, isFalse);
    expect(result.issues.map((e) => e.code), contains('invalid_deleted_at'));
  });

  test('malformed scalar and dedupe list are reported without logging data', () {
    final input = snapshot()
      ..['waffra_sms_hashes_v1'] = 'not-a-list'
      ..['waffra_monthly_budget_v1'] = -1.0;
    final result = WaffraLegacyPreflight.inspect(input);
    expect(result.canStage, isFalse);
    expect(result.issues.map((e) => e.code), contains('expected_string_list'));
    expect(result.issues.map((e) => e.code), contains('invalid_money'));
  });

  test('empty existing user data is a valid snapshot', () {
    final result = WaffraLegacyPreflight.inspect(snapshot());
    expect(result.canStage, isTrue);
    expect(result.itemCounts['entries'], 0);
  });
}
