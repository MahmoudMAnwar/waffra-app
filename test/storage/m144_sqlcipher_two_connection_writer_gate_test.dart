import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_finance_ui_patch.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

/// M144: independent SQLCipher connections sharing a disposable file and
/// participating writer gate. Never opens an installed user's database.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const category = <String, Object?>{
    'id': 'food', 'name': 'Food', 'parentId': '',
    'income': false, 'budget': 250,
  };
  const recurring = <String, Object?>{
    'id': 'rent', 'title': 'Rent', 'amount': 900,
    'income': false, 'day': 5, 'startAt': '2026-10-22T12:00:00',
  };

  late Directory root;
  late WaffraEncryptedStore first;
  late WaffraEncryptedStore second;

  WaffraAtomicFinanceSnapshot snapshot(WaffraEncryptedStore store) =>
      WaffraAtomicFinanceSnapshot(store: store, experimentalEnabled: true);

  WaffraEncryptedFinanceUiPatch writer(
    WaffraEncryptedStore store, {
    Future<void> Function()? witness,
  }) => WaffraEncryptedFinanceUiPatch(
    snapshot: snapshot(store),
    writerDirectory: root,
    experimentalEnabled: true,
    verifySourceUnderLock: witness,
  );

  Future<int> categoryBudget() async => (await first.customSelect(
    "SELECT budget_minor FROM fresh_finance_categories WHERE category_id='food'",
  ).getSingle()).read<int>('budget_minor');

  Future<int> recurringAmount() async => (await first.customSelect(
    "SELECT amount_minor FROM fresh_finance_recurring WHERE recurring_id='rent'",
  ).getSingle()).read<int>('amount_minor');

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-m144-disposable-');
    final file = File('${root.path}/isolated.sqlite');
    const key = 'm144-two-connection-disposable-key';
    first = WaffraEncryptedStore.openAt(file, key: key);
    await WaffraFreshEncryptedVaultBootstrap(
      store: first, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    await snapshot(first).initializeEmpty();
    final empty = await snapshot(first).read();
    await writer(first).saveScreenChanges(
      screenBaseline: empty.values,
      replacementValues: {
        'waffra_categories_v24': jsonEncode([category]),
        'waffra_recurring_v24': jsonEncode([recurring]),
      },
      changedKeys: const {'waffra_categories_v24', 'waffra_recurring_v24'},
    );
    second = WaffraEncryptedStore.openAt(file, key: key);
    expect((await snapshot(second).read()).generation, 1);
  });

  tearDown(() async {
    await second.close();
    await first.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('M144: same-key concurrent writers on two DB handles cannot lose an update', () async {
    final baseline = await snapshot(first).read();
    final entered = Completer<void>();
    final release = Completer<void>();
    var secondWitnessEntered = false;
    final pendingFirst = writer(first, witness: () async {
      entered.complete();
      await release.future;
    }).saveScreenChanges(
      screenBaseline: baseline.values,
      replacementValues: {
        'waffra_categories_v24': jsonEncode([{...category, 'budget': 310}]),
      },
      changedKeys: const {'waffra_categories_v24'},
    );
    await entered.future;
    final pendingSecond = writer(second, witness: () async {
      secondWitnessEntered = true;
    }).saveScreenChanges(
      screenBaseline: baseline.values,
      replacementValues: {
        'waffra_categories_v24': jsonEncode([{...category, 'budget': 320}]),
      },
      changedKeys: const {'waffra_categories_v24'},
    ).then<Object>((value) => value, onError: (Object error) => error);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(secondWitnessEntered, isFalse);
    release.complete();
    final accepted = await pendingFirst;
    expect(await pendingSecond, isA<StateError>());
    expect(secondWitnessEntered, isTrue);
    final finalState = await snapshot(second).read();
    expect(finalState.generation, baseline.generation + 1);
    expect(finalState.digest, accepted.digest);
    expect(finalState.values, accepted.values);
    expect(await categoryBudget(), 31000);
    expect(await recurringAmount(), 90000);
  });

  test('M144: two DB handles preserve unrelated concurrent module edits', () async {
    final baseline = await snapshot(first).read();
    final entered = Completer<void>();
    final release = Completer<void>();
    final pendingFirst = writer(first, witness: () async {
      entered.complete();
      await release.future;
    }).saveScreenChanges(
      screenBaseline: baseline.values,
      replacementValues: {
        'waffra_categories_v24': jsonEncode([{...category, 'budget': 360}]),
      },
      changedKeys: const {'waffra_categories_v24'},
    );
    await entered.future;
    final pendingSecond = writer(second).saveScreenChanges(
      screenBaseline: baseline.values,
      replacementValues: {
        'waffra_recurring_v24': jsonEncode([{...recurring, 'amount': 940}]),
      },
      changedKeys: const {'waffra_recurring_v24'},
    );
    release.complete();
    final firstResult = await pendingFirst;
    final secondResult = await pendingSecond;
    expect(firstResult.generation, baseline.generation + 1);
    expect(secondResult.generation, baseline.generation + 2);
    expect(await categoryBudget(), 36000);
    expect(await recurringAmount(), 94000);
    final stored = await snapshot(first).read();
    expect(stored.digest, secondResult.digest);
    expect(stored.values, secondResult.values);
  });

  test('M144: failed source witness releases shared gate for waiting DB handle', () async {
    final baseline = await snapshot(first).read();
    final entered = Completer<void>();
    final release = Completer<void>();
    final failing = writer(first, witness: () async {
      entered.complete();
      await release.future;
      throw StateError('m144-denied-source');
    }).saveScreenChanges(
      screenBaseline: baseline.values,
      replacementValues: {
        'waffra_categories_v24': jsonEncode([{...category, 'budget': 800}]),
      },
      changedKeys: const {'waffra_categories_v24'},
    ).then<Object>((value) => value, onError: (Object error) => error);
    await entered.future;
    final waiting = writer(second).saveScreenChanges(
      screenBaseline: baseline.values,
      replacementValues: {
        'waffra_categories_v24': jsonEncode([{...category, 'budget': 410}]),
      },
      changedKeys: const {'waffra_categories_v24'},
    );
    release.complete();
    final denied = await failing;
    expect(denied, isA<StateError>());
    expect(denied.toString(), contains('m144-denied-source'));
    final saved = await waiting;
    expect(saved.generation, baseline.generation + 1);
    expect(await categoryBudget(), 41000);
    expect((await snapshot(first).read()).digest, saved.digest);
  });
}
