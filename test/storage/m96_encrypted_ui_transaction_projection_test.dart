import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_finance_ui_patch.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_unified_finance_writer.dart';

/// M96 runtime-boundary regression. Synthetic-only, no main activation.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late WaffraEncryptedStore db;
  const sqlKey = 'm96-disposable-synthetic-finance-only-key';

  WaffraAtomicFinanceSnapshot state() => WaffraAtomicFinanceSnapshot(
    store: db, experimentalEnabled: true,
  );
  WaffraEncryptedFinanceUiPatch edits() => WaffraEncryptedFinanceUiPatch(
    snapshot: state(), writerDirectory: temp, experimentalEnabled: true,
  );
  WaffraUnifiedFinanceWriter confirmed() => WaffraUnifiedFinanceWriter(
    writerDirectory: temp, snapshot: state(), experimentalEnabled: true,
  );
  Map<String, Object?> data(String id, {num amount = 15.25}) => {
    'id': id, 'title': 'Synthetic purchase',
    'category': 'أخرى', 'amount': amount, 'income': false,
    'date': '2026-10-22T15:00:00', 'receiptPath': null,
  };

  Future<Map<String, Object?>> sqlEntry() async {
    final row = await db.customSelect(
      'SELECT entry_id,amount_minor,is_income,source_json '
      'FROM fresh_finance_entries',
    ).getSingle();
    return {
      'id': row.read<String>('entry_id'),
      'minor': row.read<int>('amount_minor'),
      'income': row.read<int>('is_income'),
      'source': jsonDecode(row.read<String>('source_json')),
    };
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('waffra-m96-atomic-');
    db = WaffraEncryptedStore.openAt(
      File('${temp.path}/finance.sqlite'), key: sqlKey,
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: db, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    await state().initializeEmpty();
  });
  tearDown(() async {
    await db.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('M96 edit transaction amount and category updates SQL plus UI atomically',
      () async {
    await confirmed().appendTransactions(
      records: [data('one')], messageHashes: [null], userConfirmed: true,
    );
    final loaded = await state().read();
    final next = {...data('one'), 'amount': 84.72, 'category': 'مواصلات'};
    final saved = await edits().saveScreenChanges(
      screenBaseline: loaded.values,
      replacementValues: {'entries': jsonEncode([next])},
      changedKeys: {'entries'},
    );
    expect(saved.generation, 2);
    expect((jsonDecode(saved.values['entries'] as String) as List)
        .single['amount'], 84.72);
    final relational = await sqlEntry();
    expect(relational['minor'], 8472);
    expect((relational['source'] as Map)['category'], 'مواصلات');
    await db.close();
    db = WaffraEncryptedStore.openAt(
      File('${temp.path}/finance.sqlite'), key: sqlKey,
    );
    expect((await sqlEntry())['minor'], 8472);
    expect((await state().read()).generation, 2);
  });

  test('M96 direct screen add/delete must use dedicated atomic transaction API',
      () async {
    await confirmed().appendTransactions(
      records: [data('one')], messageHashes: [null], userConfirmed: true,
    );
    final baseline = await state().read();
    for (final replacement in [
      jsonEncode([data('one'), data('unconfirmed-new')]),
      '[]',
    ]) {
      await expectLater(edits().saveScreenChanges(
        screenBaseline: baseline.values,
        replacementValues: {'entries': replacement},
        changedKeys: {'entries'},
      ), throwsA(isA<StateError>()));
    }
    expect((await sqlEntry())['minor'], 1525);
    expect((await state().read()).generation, 1);
  });

  test('M96 tampered normalized projection refuses modified finance screenshot',
      () async {
    await confirmed().appendTransactions(
      records: [data('one')], messageHashes: [null], userConfirmed: true,
    );
    final previous = await state().read();
    await db.customStatement(
      "UPDATE fresh_finance_entries SET entry_id='forged' "
      "WHERE entry_id='one'",
    );
    await expectLater(edits().saveScreenChanges(
      screenBaseline: previous.values,
      replacementValues: {
        'entries': jsonEncode([{...data('one'), 'amount': 120.50}]),
      },
      changedKeys: {'entries'},
    ), throwsA(isA<StateError>()));
    expect((await state().read()).generation, 1);
  });

  test('M96 invalid halala precision rolls back both SQL and finance snapshot',
      () async {
    await confirmed().appendTransactions(
      records: [data('one')], messageHashes: [null], userConfirmed: true,
    );
    final original = await state().read();
    await expectLater(edits().saveScreenChanges(
      screenBaseline: original.values,
      replacementValues: {
        'entries': jsonEncode([{...data('one'), 'amount': 10.005}]),
      },
      changedKeys: {'entries'},
    ), throwsA(anything));
    expect((await sqlEntry())['minor'], 1525);
    expect((await state().read()).generation, 1);
  });
}
