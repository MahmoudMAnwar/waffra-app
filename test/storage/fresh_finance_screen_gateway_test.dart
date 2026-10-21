import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_fresh_finance_screen_gateway.dart';

void main() {
  const key = 'fresh-screen-gateway-disposable-32';
  late Directory root;
  late WaffraEncryptedStore vault;
  WaffraFreshFinanceScreenGateway gateway({bool on = true}) =>
      WaffraFreshFinanceScreenGateway(
        store: vault, experimentalEnabled: on,
      );

  Future<void> init() async {
    await WaffraFreshEncryptedVaultBootstrap(
      store: vault, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
  }

  Map<String, Object?> tx({String id = 'e1', num amount = 2.75}) => {
    'id': id, 'title': 'عملية شراء', 'category': 'طعام',
    'amount': amount, 'income': false,
    'date': '2026-10-21T13:05:00', 'receiptPath': null,
  };

  setUp(() async {
    root = await Directory.systemTemp.createTemp('finance-screen-');
    vault = WaffraEncryptedStore.openAt(
      File('${root.path}/screen.sqlite'), key: key,
    );
  });
  tearDown(() async {
    await vault.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('empty dashboard state matches Waffra existing screen collection keys',
      () async {
    await init();
    final home = await gateway().readForHome();
    expect(home.totals.count, 0);
    expect(home.toScreenCollectionJson().keys.toSet(), {
      'entries',
      'waffra_categories_v24',
      'waffra_goals_v24',
      'waffra_recurring_v24',
    });
    expect(jsonDecode(home.toScreenCollectionJson()['entries']!), isEmpty);
  });

  test('transaction/goal/category/recurring changes read in screen shapes',
      () async {
    await init();
    final api = gateway();
    await api.saveTransaction(tx());
    await api.saveTransaction({
      ...tx(id: 'i1', amount: 2500.09),
      'income': true,
      'title': 'راتب',
      'category': 'دخل',
    });
    await api.saveCategory({
      'id': 'c1', 'name': 'طعام', 'income': false,
      'icon': 'restaurant', 'color': 0xFF087A54,
      'budget': 350, 'alertPercent': 80, 'parentId': '',
    });
    await api.saveGoal({
      'id': 'g1', 'name': 'رحلة', 'target': 10000,
      'saved': 65.5,
    });
    await api.saveRecurring({
      'id': 'r1', 'title': 'فاتورة شهرية',
      'category': 'فواتير', 'amount': 90,
      'income': false, 'day': 12, 'active': true,
      'startAt': '2026-10-21T11:00:00',
    });

    final state = await api.readForHome();
    expect(state.transactions, hasLength(2));
    expect(state.categories, hasLength(1));
    expect(state.goals.single['saved'], 65.5);
    expect(state.recurring.single['day'], 12);
    expect(state.totals.count, 2);
    expect(state.totals.incomeMinor, 250009);
    expect(state.totals.expenseMinor, 275);
    expect(state.transactions.map((entry) => entry['id']).toSet(), {'e1', 'i1'});
    final exported = state.toScreenCollectionJson();
    expect((jsonDecode(exported['entries']!) as List), hasLength(2));
    expect((jsonDecode(exported['waffra_goals_v24']!) as List)
        .first['name'], 'رحلة');
  });

  test('screen edits update exact cash amounts, not create a duplicate',
      () async {
    await init();
    await gateway().saveTransaction(tx());
    await gateway().saveTransaction(tx(amount: 2.95), replaceExisting: true);
    expect((await gateway().readForHome()).totals.expenseMinor, 295);
    expect((await gateway().readForHome()).transactions, hasLength(1));
  });

  test('receipt-bearing writes are refused until file cutover is safe',
      () async {
    await init();
    await expectLater(
      gateway().saveTransaction({
        ...tx(), 'receiptPath': '/existing/private/receipt.jpg',
      }), throwsA(isA<StateError>()),
    );
    expect((await gateway().readForHome()).totals.count, 0);
  });

  test('bad mandatory money/date and deleted data do not silently get stored',
      () async {
    await init();
    for (final invalid in [
      {...tx(), 'amount': 1.005},
      {...tx(), 'amount': -2},
      {...tx(), 'date': 'not-a-date'},
      {...tx(), 'title': ''},
      {...tx(), 'id': ''},
      {...tx(), 'income': 'false'},
    ]) {
      await expectLater(
        gateway().saveTransaction(invalid),
        throwsA(isA<ArgumentError>()),
      );
    }
    expect((await gateway().readForHome()).transactions, isEmpty);
  });

  test('all finance gateways fail closed until expressly enabled', () async {
    await init();
    await expectLater(gateway(on: false).readForHome(),
        throwsA(isA<StateError>()));
    await expectLater(gateway(on: false).saveTransaction(tx()),
        throwsA(isA<StateError>()));
    await expectLater(gateway(on: false).saveGoal({
      'id': 'g1', 'name': 'Trip', 'target': 100, 'saved': 0,
    }), throwsA(isA<StateError>()));
    expect((await gateway().readForHome()).goals, isEmpty);
  });

  test('cold reopening a database retains exact screen finance collections',
      () async {
    await init();
    await gateway().saveTransaction(tx(amount: 190.25));
    await gateway().saveGoal({
      'id': 'g1', 'name': 'مدخرات', 'target': 300, 'saved': 10,
    });
    await vault.close();
    vault = WaffraEncryptedStore.openAt(
      File('${root.path}/screen.sqlite'), key: key,
    );
    final state = await gateway().readForHome();
    expect(state.transactions.single['amount'], 190.25);
    expect(state.goals.single['saved'], 10);
    expect(state.totals.expenseMinor, 19025);
  });
}
