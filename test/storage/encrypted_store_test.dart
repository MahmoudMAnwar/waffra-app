import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';

void main() {
  late Directory temp;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('waffra-encrypted-test-');
  });
  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  final secret = 'test-only-secret-32-bytes-not-for-users';
  Map<String, Object?> snapshot({num amount = 25.50}) => {
        'entries': jsonEncode([
          {
            'id': 'entry-1',
            'title': 'مشتريات / Offline',
            'category': 'مأكولات',
            'amount': amount,
            'income': false,
            'date': '2026-10-21T11:30:00',
            'receiptPath': jsonEncode(['/receipts/1.jpg', '/receipts/2.jpg']),
          },
          {
            'id': 'entry-2',
            'title': 'Salary',
            'category': 'راتب',
            'amount': 125.75,
            'income': true,
            'date': '2026-10-20T11:30:00',
            'receiptPath': null,
          }
        ]),
        'waffra_categories_v24': jsonEncode([
          {
            'id': 'cat-1',
            'name': 'مأكولات',
            'icon': 'restaurant',
            'color': 0xFF087A54,
            'income': false,
            'parentId': '',
            'budget': 400,
            'alertPercent': 80,
          }
        ]),
        'waffra_goals_v24': jsonEncode([
          {'id': 'goal-1', 'name': 'رحلة', 'target': 9000, 'saved': 100}
        ]),
        'waffra_recurring_v24': '[]',
        'waffra_challenges_v1': '[]',
        'waffra_deleted_categories_v1': '[]',
        'waffra_deleted_goals_v1': '[]',
        'waffra_deleted_recurring_v1': '[]',
        'waffra_recurring_postponed_v1': '{}',
        'waffra_learned_merchants_v1': '{}',
        'waffra_sms_hashes_v1': <String>['hash-1'],
        'waffra_monthly_budget_v1': 2000.0,
        'waffra_monthly_budget_enabled_v1': true,
        'waffra_recurring_reminders_enabled_v1': false,
      };

  test('encrypted native store reopens with same key and never exposes plain SQLite header', () async {
    final file = File('${temp.path}/vault.sqlite');
    final store = WaffraEncryptedStore.openAt(file, key: secret);
    final source = snapshot();
    final result = await store.stageSnapshot('vault-a', source);
    expect(result.recordCount, greaterThan(2));
    expect(result.incomeMinor, 12575);
    expect(result.expenseMinor, 2550);
    expect(result.receiptReferences, 2);
    expect(await store.stagedRowCount('vault-a'), result.recordCount);
    await store.close();

    final bytes = await file.readAsBytes();
    expect(bytes.length, greaterThan(20));
    expect(bytes.take(16).toList(), isNot(utf8.encode('SQLite format 3\u0000')));
    final reopened = WaffraEncryptedStore.openAt(file, key: secret);
    expect(await reopened.stagedRowCount('vault-a'), result.recordCount);
    final repeat = await reopened.stageSnapshot('vault-a', source);
    expect(repeat.sourceSha256, result.sourceSha256);
    expect(await reopened.stagedRowCount('vault-a'), result.recordCount);
    await reopened.close();
  });

  test('wrong key cannot read encrypted vault', () async {
    final file = File('${temp.path}/vault.sqlite');
    final store = WaffraEncryptedStore.openAt(file, key: secret);
    await store.stageSnapshot('vault-a', snapshot());
    await store.close();
    final incorrect = WaffraEncryptedStore.openAt(
      file, key: 'definitely-a-different-test-key-123456',
    );
    await expectLater(incorrect.stagedRowCount('vault-a'), throwsA(isA<Exception>()));
    await incorrect.close();
  });

  test('preflight failure never stages or mutates source values', () async {
    final file = File('${temp.path}/vault.sqlite');
    final store = WaffraEncryptedStore.openAt(file, key: secret);
    final source = snapshot(amount: 2.005);
    final before = jsonEncode(source);
    await expectLater(
      store.stageSnapshot('vault-a', source),
      throwsA(isA<StateError>()),
    );
    expect(jsonEncode(source), before);
    expect(await store.stagedRowCount('vault-a'), 0);
    await store.close();
  });

  test('import for second vault is isolated and same-vault changed snapshot is rejected', () async {
    final file = File('${temp.path}/vault.sqlite');
    final store = WaffraEncryptedStore.openAt(file, key: secret);
    final first = await store.stageSnapshot('vault-a', snapshot());
    final next = await store.stageSnapshot('vault-b', snapshot(amount: 9));
    expect(await store.stagedRowCount('vault-a'), first.recordCount);
    expect(await store.stagedRowCount('vault-b'), next.recordCount);
    await expectLater(
      store.stageSnapshot('vault-a', snapshot(amount: 9)),
      throwsA(isA<StateError>()),
    );
    expect(await store.stagedRowCount('vault-a'), first.recordCount);
    await store.close();
  });
}
