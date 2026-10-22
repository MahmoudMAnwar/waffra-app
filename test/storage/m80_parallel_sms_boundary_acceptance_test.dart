import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_confirmed_sms_batch_writer.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_fresh_ledger_repository.dart';

/// M80 independent, synthetic-only QA. No live UI cutover, account access,
/// production key, bank data, Firebase connection or Android emulator needed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory sandbox;
  late WaffraEncryptedStore db;
  const testKey = 'm80-disposable-synthetic-sms-key-only';

  String fingerprint(int index) =>
      index.toRadixString(16).padLeft(64, '0');

  WaffraConfirmedSmsEntry synthetic(
    int index, {
    String? id,
    String? messageHash,
    bool income = false,
    int amountMinor = 125,
  }) =>
      WaffraConfirmedSmsEntry(
        id: id ?? 'synthetic-$index',
        messageHash: messageHash ?? fingerprint(index),
        displayTitle: income ? 'Synthetic income' : 'Synthetic expense',
        category: income ? 'دخل آخر' : 'أخرى',
        amountMinor: amountMinor,
        isIncome: income,
        occurredIso: '2026-10-22T12:00:00',
      );

  WaffraConfirmedSmsBatchWriter writer() =>
      WaffraConfirmedSmsBatchWriter(store: db, experimentalEnabled: true);

  Future<int> rowCount(String table) async {
    final row = await db.customSelect('SELECT count(*) AS n FROM $table')
        .getSingle();
    return row.read<int>('n');
  }

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('waffra-m80-sms-');
    db = WaffraEncryptedStore.openAt(
      File('${sandbox.path}/sms.sqlite'), key: testKey,
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: db, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
  });

  tearDown(() async {
    await db.close();
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  test('M80 exactly 100 confirmed records save accurate income/expense totals',
      () async {
    final batch = List.generate(
      100,
      (n) => synthetic(
        n + 1,
        income: n.isEven,
        amountMinor: n.isEven ? 125 : 250,
      ),
    );
    final result = await writer().saveConfirmed(
      userConfirmed: true, records: batch,
    );
    expect(result.detected, 100);
    expect(result.saved, 100);
    expect(result.savedIncome, 50);
    expect(result.savedExpenses, 50);
    expect(result.skippedDuplicates, 0);
    expect(result.incomeMinor, 6250);
    expect(result.expensesMinor, 12500);
    expect(await rowCount('fresh_finance_entries'), 100);
    expect(await rowCount('fresh_finance_sms_hashes'), 100);
    final totals = await WaffraFreshLedgerRepository(
      store: db, experimentalEnabled: true,
    ).totals();
    expect(totals.count, 100);
    expect(totals.incomeMinor, 6250);
    expect(totals.expenseMinor, 12500);
  });

  test('M80 101st message rejects whole batch before saving even one hash',
      () async {
    await expectLater(
      writer().saveConfirmed(
        userConfirmed: true,
        records: List.generate(101, (n) => synthetic(n + 1)),
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(await rowCount('fresh_finance_entries'), 0);
    expect(await rowCount('fresh_finance_sms_hashes'), 0);
  });

  test('M80 rejection of a 100-message unconfirmed batch persists nothing',
      () async {
    await expectLater(
      writer().saveConfirmed(
        userConfirmed: false,
        records: List.generate(100, (n) => synthetic(n + 1)),
      ),
      throwsA(isA<StateError>()),
    );
    expect(await rowCount('fresh_finance_entries'), 0);
    expect(await rowCount('fresh_finance_sms_hashes'), 0);
  });

  test('M80 late duplicate ID rolls back 99 earlier rows and their hashes',
      () async {
    final records = List.generate(100, (n) => synthetic(n + 1));
    records[99] = synthetic(100, id: 'synthetic-1');
    await expectLater(
      writer().saveConfirmed(userConfirmed: true, records: records),
      throwsA(anything),
    );
    expect(await rowCount('fresh_finance_entries'), 0);
    expect(await rowCount('fresh_finance_sms_hashes'), 0);

    await db.close();
    db = WaffraEncryptedStore.openAt(
      File('${sandbox.path}/sms.sqlite'), key: testKey,
    );
    expect(await rowCount('fresh_finance_entries'), 0);
    expect(await rowCount('fresh_finance_sms_hashes'), 0);
  });

  test('M80 replay after cold restart skips duplicates but saves new records',
      () async {
    await writer().saveConfirmed(
      userConfirmed: true,
      records: List.generate(8, (n) => synthetic(n + 1)),
    );
    await db.close();
    db = WaffraEncryptedStore.openAt(
      File('${sandbox.path}/sms.sqlite'), key: testKey,
    );
    final replay = [
      for (var n = 1; n <= 8; n++)
        synthetic(n, id: 'replay-$n'),
      synthetic(9),
    ];
    final result = await writer().saveConfirmed(
      userConfirmed: true, records: replay,
    );
    expect(result.detected, 9);
    expect(result.saved, 1);
    expect(result.savedIncome, 0);
    expect(result.savedExpenses, 1);
    expect(result.skippedDuplicates, 8);
    expect(await rowCount('fresh_finance_entries'), 9);
    expect(await rowCount('fresh_finance_sms_hashes'), 9);
  });
}
