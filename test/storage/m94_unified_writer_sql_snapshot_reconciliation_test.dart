import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_unified_finance_writer.dart';

/// M94 synthetic Home+Widget integration at the encrypted writer boundary.
/// Production widgets and main.dart remain unchanged and unactivated.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late WaffraEncryptedStore database;
  const key = 'm94-private-synthetic-concurrent-writer-key';

  WaffraAtomicFinanceSnapshot snapshot() => WaffraAtomicFinanceSnapshot(
    store: database, experimentalEnabled: true,
  );

  WaffraUnifiedFinanceWriter writer() => WaffraUnifiedFinanceWriter(
    writerDirectory: root, snapshot: snapshot(), experimentalEnabled: true,
  );

  Map<String, Object?> record(String id, {bool income = false}) => {
    'id': id, 'title': 'Synthetic $id',
    'category': income ? 'دخل' : 'أخرى',
    'amount': income ? 100.25 : 84.72,
    'income': income, 'date': '2026-10-22T15:00:00',
    'receiptPath': null,
  };

  String hash(int n) => n.toRadixString(16).padLeft(64, '0');

  Future<int> sqlCount() async =>
      (await database.customSelect(
        'SELECT count(*) AS n FROM fresh_finance_entries',
      ).getSingle()).read<int>('n');

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-m94-writer-');
    database = WaffraEncryptedStore.openAt(
      File('${root.path}/finance.sqlite'), key: key,
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: database, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    await snapshot().initializeEmpty();
  });
  tearDown(() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('M94 concurrent Home/Widget commits preserve SQL and snapshot IDs',
      () async {
    final outcomes = await Future.wait([
      writer().appendTransactions(
        records: [record('home-manual', income: true)],
        messageHashes: [null], userConfirmed: true,
      ),
      writer().appendTransactions(
        records: [record('widget-sms')],
        messageHashes: [hash(1)], userConfirmed: true,
      ),
    ]);
    expect(outcomes.map((r) => r.saved).toList(), [1, 1]);
    expect(await sqlCount(), 2);
    final state = await snapshot().read();
    expect(state.generation, 2);
    final ids = (jsonDecode(state.values['entries'] as String) as List)
        .map((e) => (e as Map)['id']).toSet();
    final sqlRows = await database.customSelect(
      'SELECT entry_id FROM fresh_finance_entries',
    ).get();
    expect(sqlRows.map((e) => e.read<String>('entry_id')).toSet(), ids);
    expect(state.values['waffra_sms_hashes_v1'], [hash(1)]);
  });

  test('M94 equal-sized but mismatched SQL ledger fails closed before save',
      () async {
    await writer().appendTransactions(
      records: [record('original')],
      messageHashes: [hash(2)], userConfirmed: true,
    );
    await database.customStatement(
      "UPDATE fresh_finance_entries SET entry_id='forged' "
      "WHERE entry_id='original'",
    );
    await expectLater(writer().appendTransactions(
      records: [record('must-not-write')],
      messageHashes: [hash(3)], userConfirmed: true,
    ), throwsA(isA<StateError>()));
    expect(await sqlCount(), 1);
    final saved = await snapshot().read();
    expect(saved.generation, 1);
    expect(saved.values['waffra_sms_hashes_v1'], [hash(2)]);
  });

  test('M94 late duplicate transaction ID rolls back all confirmed SMS hashes',
      () async {
    await expectLater(writer().appendTransactions(
      records: [record('repeat'), record('repeat')],
      messageHashes: [hash(5), hash(6)],
      userConfirmed: true,
    ), throwsA(isA<StateError>()));
    expect(await sqlCount(), 0);
    final state = await snapshot().read();
    expect(state.generation, 0);
    expect(state.values.containsKey('waffra_sms_hashes_v1'), isFalse);
  });

  test('M94 unconfirmed SMS never enters normalized or canonical ledger',
      () async {
    await expectLater(writer().appendTransactions(
      records: [record('cancelled')],
      messageHashes: [hash(7)], userConfirmed: false,
    ), throwsA(isA<StateError>()));
    expect(await sqlCount(), 0);
    expect((await snapshot().read()).generation, 0);
  });
}
