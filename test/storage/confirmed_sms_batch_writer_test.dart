import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_confirmed_sms_batch_writer.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_fresh_ledger_repository.dart';

void main() {
  late Directory root;
  late WaffraEncryptedStore vault;
  const key = 'waffra-pasted-sms-disposable-key-32';

  WaffraConfirmedSmsBatchWriter writer({bool enabled = true}) =>
      WaffraConfirmedSmsBatchWriter(
        store: vault, experimentalEnabled: enabled,
      );

  String hash(int n) => n.toRadixString(16).padLeft(64, '0');
  WaffraConfirmedSmsEntry item(
    int n, {
    bool income = false,
    int amountMinor = 500,
    String? entryId,
    String? messageHash,
  }) => WaffraConfirmedSmsEntry(
    id: entryId ?? 'pasted-$n',
    messageHash: messageHash ?? hash(n),
    displayTitle: income ? 'راتب تجريبي' : 'مشتريات تجريبية',
    category: income ? 'دخل' : 'طعام',
    amountMinor: amountMinor,
    isIncome: income,
    occurredIso: '2026-10-21T14:00:00',
  );

  Future<void> init() async {
    await WaffraFreshEncryptedVaultBootstrap(
      store: vault, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
  }

  Future<int> countHashes() async {
    final result = await vault.customSelect(
      'SELECT count(*) AS n FROM fresh_finance_sms_hashes',
    ).getSingle();
    return result.read<int>('n');
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-sms-ledger-');
    vault = WaffraEncryptedStore.openAt(
      File('${root.path}/sms.sqlite'), key: key,
    );
  });
  tearDown(() async {
    await vault.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('requires explicit confirmation; no save from parsing or preview',
      () async {
    await init();
    await expectLater(
      writer().saveConfirmed(userConfirmed: false, records: [item(1)]),
      throwsA(isA<StateError>()),
    );
    expect((await WaffraFreshLedgerRepository(
      store: vault, experimentalEnabled: true,
    ).totals()).count, 0);
    expect(await countHashes(), 0);
  });

  test('five pasted messages persist two incomes and three expenses',
      () async {
    await init();
    final records = [
      item(1, income: true, amountMinor: 140000),
      item(2, income: false, amountMinor: 200),
      item(3, income: false, amountMinor: 1125),
      item(4, income: true, amountMinor: 3900),
      item(5, income: false, amountMinor: 510),
    ];
    final result = await writer().saveConfirmed(
      userConfirmed: true, records: records,
    );
    expect(result.detected, 5);
    expect(result.saved, 5);
    expect(result.savedIncome, 2);
    expect(result.savedExpenses, 3);
    expect(result.skippedDuplicates, 0);
    expect(result.incomeMinor, 143900);
    expect(result.expensesMinor, 1835);
    expect(await countHashes(), 5);
    final ledger = WaffraFreshLedgerRepository(
      store: vault, experimentalEnabled: true,
    );
    final totals = await ledger.totals();
    expect(totals.count, 5);
    expect(totals.incomeMinor, 143900);
    expect(totals.expenseMinor, 1835);
  });

  test('second identical paste reports real duplicate skips, not fake saves',
      () async {
    await init();
    await writer().saveConfirmed(userConfirmed: true, records: [item(1)]);
    final result = await writer().saveConfirmed(
      userConfirmed: true,
      records: [item(1, entryId: 'another-id'), item(2)],
    );
    expect(result.detected, 2);
    expect(result.saved, 1);
    expect(result.skippedDuplicates, 1);
    expect(await countHashes(), 2);
    final totals = await WaffraFreshLedgerRepository(
      store: vault, experimentalEnabled: true,
    ).totals();
    expect(totals.count, 2);
  });

  test('same message in same paste is stored once by default', () async {
    await init();
    final result = await writer().saveConfirmed(
      userConfirmed: true,
      records: [
        item(1),
        item(2, messageHash: hash(1)),
      ],
    );
    expect(result.saved, 1);
    expect(result.skippedDuplicates, 1);
    expect(await countHashes(), 1);
  });

  test('duplicates require explicit opt-in, retaining one dedupe hash',
      () async {
    await init();
    final result = await writer().saveConfirmed(
      userConfirmed: true,
      allowDuplicates: true,
      records: [
        item(1),
        item(2, messageHash: hash(1)),
      ],
    );
    expect(result.saved, 2);
    expect(result.skippedDuplicates, 0);
    expect(await countHashes(), 1);
  });

  test('more than 100 messages rejected before any SQL change', () async {
    await init();
    await expectLater(
      writer().saveConfirmed(
        userConfirmed: true,
        records: List.generate(101, (n) => item(n + 1)),
      ), throwsA(isA<ArgumentError>()),
    );
    expect(await countHashes(), 0);
  });

  test('failure after first insert rolls back all finance rows and hashes',
      () async {
    await init();
    await expectLater(
      writer().saveConfirmed(
        userConfirmed: true,
        records: [
          item(1, entryId: 'duplicate-id'),
          item(2, entryId: 'duplicate-id'),
        ],
      ), throwsA(isA<Exception>()),
    );
    expect(await countHashes(), 0);
    final totals = await WaffraFreshLedgerRepository(
      store: vault, experimentalEnabled: true,
    ).totals();
    expect(totals.count, 0);
  });

  test('invalid amount, ID and hash refuse partial persistence',
      () async {
    await init();
    for (final invalid in [
      item(1, amountMinor: 0),
      item(1, entryId: ''),
      item(1, messageHash: 'wrong'),
    ]) {
      await expectLater(
        writer().saveConfirmed(userConfirmed: true, records: [item(2), invalid]),
        throwsA(isA<ArgumentError>()),
      );
    }
    expect(await countHashes(), 0);
  });

  test('no inserts when disabled even if user confirmed', () async {
    await init();
    await expectLater(
      writer(enabled: false).saveConfirmed(
        userConfirmed: true, records: [item(1)],
      ), throwsA(isA<StateError>()),
    );
    expect(await countHashes(), 0);
  });

  test('durable dedupe survives cold reopen without retaining raw SMS', () async {
    await init();
    await writer().saveConfirmed(userConfirmed: true, records: [item(1)]);
    await vault.close();
    vault = WaffraEncryptedStore.openAt(
      File('${root.path}/sms.sqlite'), key: key,
    );
    final result = await writer().saveConfirmed(
      userConfirmed: true,
      records: [item(1, entryId: 'replay')],
    );
    expect(result.saved, 0);
    expect(result.skippedDuplicates, 1);
    expect(await countHashes(), 1);
    final source = await vault.customSelect(
      'SELECT source_json FROM fresh_finance_entries',
    ).getSingle();
    expect(source.read<String>('source_json'), isNot(contains('bank_account')));
  });
}
