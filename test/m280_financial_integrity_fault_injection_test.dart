import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_unified_finance_writer.dart';

/// Disposable SQLCipher source testing; NOT proof of production cutover.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late WaffraEncryptedStore store;
  WaffraAtomicFinanceSnapshot snapshot() => WaffraAtomicFinanceSnapshot(
      store: store, experimentalEnabled: true);
  WaffraUnifiedFinanceWriter writer() => WaffraUnifiedFinanceWriter(
      writerDirectory: directory, snapshot: snapshot(),
      experimentalEnabled: true);
  Map<String, Object?> entry(String id, int cents, {bool income = false}) => {
    'id': id, 'title': 'M280 synthetic $id',
    'category': income ? 'Income' : 'Expense',
    'amount': cents / 100, 'income': income,
    'date': '2026-10-27T12:00:00', 'receiptPath': null,
  };
  String hash(int n) => n.toRadixString(16).padLeft(64, '0');
  Future<List<dynamic>> entries() async =>
      jsonDecode((await snapshot().read()).values['entries'] as String? ?? '[]') as List;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('m280-disposable-');
    store = WaffraEncryptedStore.openAt(
      File('${directory.path}/finance.sqlite'),
      key: 'm280-disposable-encrypted-store-only-key',
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: store, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    await snapshot().initializeEmpty();
  });
  tearDown(() async {
    await store.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('M280 exact cent accounting for 100 confirmed income and expenses', () async {
    final records = [
      ...List.generate(60, (i) => entry('income-$i', 133, income: true)),
      ...List.generate(40, (i) => entry('expense-$i', 219)),
    ];
    final result = await writer().appendTransactions(
      records: records,
      messageHashes: List<String?>.filled(100, null),
      userConfirmed: true,
    );
    expect(result.saved, 100);
    expect(result.savedIncome, 60);
    expect(result.savedExpenses, 40);
    expect(result.incomeMinor, 7980);
    expect(result.expenseMinor, 8760);
    expect((await entries()).length, 100);
    final actual = await entries();
    final net = actual.fold<int>(0, (sum, item) =>
        sum + ((item as Map)['income'] as bool ? 1 : -1) *
        (((item['amount'] as num) * 100).round()));
    expect(net, -780);
    expect((await snapshot().read()).generation, 1);
  });

  test('M280 parallel app/widget saves retain all 96 distinct finance rows', () async {
    final writes = List.generate(8, (batch) => writer().appendTransactions(
      records: List.generate(12, (i) => entry('batch-$batch-entry-$i', 105)),
      messageHashes: List<String?>.filled(12, null),
      userConfirmed: true,
    ));
    final results = await Future.wait(writes);
    expect(results.every((item) => item.saved == 12), isTrue);
    final list = await entries();
    expect(list.length, 96);
    expect(list.map((item) => (item as Map)['id']).toSet().length, 96);
    expect((await snapshot().read()).generation, 8);
  });

  test('M280 bad amount rolls back entire mixed batch and SMS hashes', () async {
    await writer().appendTransactions(
      records: [entry('first', 500)],
      messageHashes: [hash(1)], userConfirmed: true,
    );
    final before = await snapshot().read();
    await expectLater(writer().appendTransactions(
      records: [entry('second', 270), {...entry('invalid', 155), 'amount': 1.005}],
      messageHashes: [hash(2), hash(3)],
      userConfirmed: true,
    ), throwsA(anything));
    final after = await snapshot().read();
    expect(after.generation, before.generation);
    expect(after.digest, before.digest);
    expect(after.values['waffra_sms_hashes_v1'], [hash(1)]);
    expect((await entries()).length, 1);
  });

  test('M280 double-confirm same bank message is idempotent', () async {
    final actions = await Future.wait([
      writer().appendTransactions(records: [entry('click-one', 890)],
          messageHashes: [hash(90)], userConfirmed: true),
      writer().appendTransactions(records: [entry('click-two', 890)],
          messageHashes: [hash(90)], userConfirmed: true),
    ]);
    expect(actions.fold<int>(0, (n, result) => n + result.saved), 1);
    expect(actions.fold<int>(0, (n, result) => n + result.skippedDuplicates), 1);
    expect((await entries()).length, 1);
    expect((await snapshot().read()).generation, 1);
  });

  test('M280 cold restart preserves encrypted ledger and digest', () async {
    await writer().appendTransactions(
      records: [entry('before-restart', 999, income: true)],
      messageHashes: [null], userConfirmed: true,
    );
    final before = await snapshot().read();
    await store.close();
    store = WaffraEncryptedStore.openAt(
      File('${directory.path}/finance.sqlite'),
      key: 'm280-disposable-encrypted-store-only-key',
    );
    final after = await snapshot().read();
    expect(after.digest, before.digest);
    expect(after.generation, before.generation);
    expect((await entries()).single['id'], 'before-restart');
  });

  test('M280 old screen revision cannot overwrite newer widget record', () async {
    final original = await snapshot().read();
    await writer().appendTransactions(
      records: [entry('newer-widget', 450)],
      messageHashes: [null], userConfirmed: true,
    );
    await expectLater(snapshot().commit(
      expectedGeneration: original.generation,
      fullFinanceSnapshot: {
        ...original.values,
        'entries': jsonEncode([entry('stale-screen', 9999)]),
      },
    ), throwsA(isA<StateError>()));
    expect((await entries()).single['id'], 'newer-widget');
  });

  test('M280 >100 SMS records rejected without partial writes', () async {
    await expectLater(writer().appendTransactions(
      records: List.generate(101, (i) => entry('over-$i', 100)),
      messageHashes: List<String?>.filled(101, null),
      userConfirmed: true,
    ), throwsArgumentError);
    expect(await entries(), isEmpty);
    expect((await snapshot().read()).generation, 0);
  });

  test('M280 rapid saves preserve unrelated goals and category snapshots', () async {
    const goals = '[{"id":"qa-goal","name":"Synthetic","target":5000,"saved":200}]';
    const categories = '[]';
    await snapshot().commit(expectedGeneration: 0, fullFinanceSnapshot: {
      'waffra_goals_v24': goals,
      'waffra_categories_v24': categories,
      'entries': '[]',
    });
    await Future.wait(List.generate(6, (i) => writer().appendTransactions(
      records: [entry('preserve-$i', 75)],
      messageHashes: [null], userConfirmed: true,
    )));
    final values = (await snapshot().read()).values;
    expect(values['waffra_goals_v24'], goals);
    expect(values['waffra_categories_v24'], categories);
    expect((await entries()).length, 6);
  });
}
