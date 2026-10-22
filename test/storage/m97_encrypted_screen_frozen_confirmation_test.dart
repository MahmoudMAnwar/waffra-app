import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_finance_ui_patch.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_unified_finance_writer.dart';

/// M97 proves finance forms cannot mutate the user-confirmed transaction
/// while a native lock or source witness is awaited. Synthetic-only vault.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late WaffraEncryptedStore vault;
  const testKey = 'm97-private-synthetic-witness-freeze-key';

  WaffraAtomicFinanceSnapshot snapshot() => WaffraAtomicFinanceSnapshot(
    store: vault, experimentalEnabled: true,
  );

  WaffraEncryptedFinanceUiPatch edit({
    Future<void> Function()? sourceWitness,
  }) => WaffraEncryptedFinanceUiPatch(
    snapshot: snapshot(),
    writerDirectory: directory,
    verifySourceUnderLock: sourceWitness,
    experimentalEnabled: true,
  );

  Map<String, Object?> transaction({num amount = 15.25,
      String? receiptPath}) => {
    'id': 'm97-entry',
    'title': 'Synthetic purchase',
    'category': 'أخرى',
    'amount': amount,
    'income': false,
    'date': '2026-10-22T12:00:00',
    'receiptPath': receiptPath,
  };

  Future<void> seed() => WaffraUnifiedFinanceWriter(
    writerDirectory: directory, snapshot: snapshot(),
    experimentalEnabled: true,
  ).appendTransactions(
    records: [transaction()], messageHashes: [null],
    userConfirmed: true,
  ).then((_) {});

  Future<int> sqlMinor() async =>
      (await vault.customSelect(
        "SELECT amount_minor FROM fresh_finance_entries "
        "WHERE entry_id='m97-entry'",
      ).getSingle()).read<int>('amount_minor');

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('waffra-m97-freeze-');
    vault = WaffraEncryptedStore.openAt(
      File('${directory.path}/vault.sqlite'), key: testKey,
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: vault, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    await snapshot().initializeEmpty();
  });
  tearDown(() async {
    await vault.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('M97 edited transaction snapshot is frozen before await source witness',
      () async {
    await seed();
    final loaded = await snapshot().read();
    final baseline = Map<String, Object?>.from(loaded.values);
    final changed = <String, Object?>{
      'entries': jsonEncode([transaction(amount: 84.72)]),
    };
    final entered = Completer<void>();
    final unblock = Completer<void>();
    final pending = edit(sourceWitness: () async {
      entered.complete();
      await unblock.future;
    }).saveScreenChanges(
      screenBaseline: baseline,
      replacementValues: changed,
      changedKeys: {'entries'},
    );
    await entered.future;
    baseline['entries'] = '[]';
    changed['entries'] = jsonEncode([transaction(amount: 999.99)]);
    unblock.complete();

    final saved = await pending;
    expect(saved.generation, 2);
    expect((jsonDecode(saved.values['entries'] as String) as List)
        .single['amount'], 84.72);
    expect(await sqlMinor(), 8472);
  });

  test('M97 changed-key set cannot expand while native lock is awaiting',
      () async {
    await seed();
    final baseline = await snapshot().read();
    final keys = <String>{'waffra_monthly_budget_v1'};
    final replacements = <String, Object?>{
      'waffra_monthly_budget_v1': 700.0,
      'entries': jsonEncode([transaction(amount: 999)]),
    };
    final entered = Completer<void>();
    final release = Completer<void>();
    final pending = edit(sourceWitness: () async {
      entered.complete();
      await release.future;
    }).saveScreenChanges(
      screenBaseline: baseline.values,
      replacementValues: replacements,
      changedKeys: keys,
    );
    await entered.future;
    keys.add('entries');
    release.complete();
    final saved = await pending;
    expect(saved.values['waffra_monthly_budget_v1'], 700.0);
    expect(await sqlMinor(), 1525);
  });

  test('M97 receipt location changes require a dedicated encrypted file writer',
      () async {
    await seed();
    final current = await snapshot().read();
    await expectLater(edit().saveScreenChanges(
      screenBaseline: current.values,
      replacementValues: {
        'entries': jsonEncode([
          transaction(receiptPath: '/tmp/unsafe-invoice.jpg'),
        ]),
      },
      changedKeys: {'entries'},
    ), throwsA(isA<StateError>()));
    expect(await sqlMinor(), 1525);
    expect((await snapshot().read()).generation, 1);
  });

  test('M97 invalid transaction amount rolls back unrelated budget edit too',
      () async {
    await seed();
    final old = await snapshot().read();
    await expectLater(edit().saveScreenChanges(
      screenBaseline: old.values,
      replacementValues: {
        'entries': jsonEncode([transaction(amount: 1.005)]),
        'waffra_monthly_budget_v1': 350.0,
      },
      changedKeys: {'entries', 'waffra_monthly_budget_v1'},
    ), throwsA(anything));
    final after = await snapshot().read();
    expect(after.generation, 1);
    expect(after.values.containsKey('waffra_monthly_budget_v1'), isFalse);
    expect(await sqlMinor(), 1525);
  });
}
