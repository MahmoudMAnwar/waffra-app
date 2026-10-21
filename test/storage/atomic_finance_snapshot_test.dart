import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

void main() {
  late Directory root;
  late WaffraEncryptedStore vault;
  const key = 'test-only-atomic-fully-encrypted-key';

  WaffraAtomicFinanceSnapshot snapshot({bool enabled = true}) =>
      WaffraAtomicFinanceSnapshot(store: vault, experimentalEnabled: enabled);

  Map<String, Object?> finance({
    num salary = 3250.25,
    num expense = 99.75,
  }) => {
    'entries': jsonEncode([
      {
        'id': 'salary',
        'title': 'راتب',
        'category': 'دخل',
        'amount': salary,
        'income': true,
        'date': '2026-10-21T12:00:00',
        'receiptPath': null,
      },
      {
        'id': 'expense',
        'title': 'مشتريات',
        'category': 'مأكولات',
        'amount': expense,
        'income': false,
        'date': '2026-10-21T13:00:00',
        'receiptPath': null,
      },
    ]),
    'waffra_categories_v24': jsonEncode([
      {'id':'food','name':'طعام','budget':500,
       'income':false,'icon':'restaurant','color':0xFF087A54},
    ]),
    'waffra_goals_v24': jsonEncode([
      {'id':'goal-1','name':'رحلة','target':3000,'saved':750},
    ]),
    'waffra_recurring_v24': jsonEncode([
      {'id':'r1','title':'إنترنت','amount':150,
       'income':false,'day':15,'startAt':'2026-10-01T00:00:00'},
    ]),
    'waffra_challenges_v1':'[]',
    'waffra_deleted_categories_v1':'[]',
    'waffra_deleted_goals_v1':'[]',
    'waffra_deleted_recurring_v1':'[]',
    'waffra_recurring_postponed_v1':'{}',
    'waffra_learned_merchants_v1':'{}',
    'waffra_sms_hashes_v1': <String>['hash-test'],
    'waffra_monthly_budget_v1':1200.50,
    'waffra_monthly_budget_enabled_v1':true,
    'waffra_recurring_reminders_enabled_v1':false,
  };

  Future<void> ready() async {
    await WaffraFreshEncryptedVaultBootstrap(
      store:vault,experimentalEnabled:true,
    ).initialize(decision:WaffraFirstRunDecision.freshCandidate);
  }

  setUp(() async {
    root=await Directory.systemTemp.createTemp('waffra-full-snapshot-');
    vault=WaffraEncryptedStore.openAt(
      File('${root.path}/full.sqlite'),key:key,
    );
  });
  tearDown(() async {
    await vault.close();
    if(await root.exists())await root.delete(recursive:true);
  });

  test('fresh vault initializes empty, with no sample finance records',
      () async {
    await ready();
    final first=await snapshot().initializeEmpty();
    expect(first.generation,0);
    expect(first.values,isEmpty);
    expect((await snapshot().read()).digest,first.digest);
  });

  test('all finance keys are atomically committed with exact original values',
      () async {
    await ready();
    await snapshot().initializeEmpty();
    final data=finance();
    final first=await snapshot().commit(
      expectedGeneration:0,fullFinanceSnapshot:data,
    );
    expect(first.generation,1);
    expect(first.values.keys.toSet(),data.keys.toSet());
    expect(first.values['entries'],data['entries']);
    expect(first.values['waffra_goals_v24'],data['waffra_goals_v24']);
    expect(first.values['waffra_sms_hashes_v1'],['hash-test']);
    expect(first.values['waffra_monthly_budget_v1'],1200.50);
    expect((await snapshot().read()).digest,first.digest);
  });

  test('missing keys stay absent rather than resetting user app settings',
      () async {
    await ready();
    await snapshot().initializeEmpty();
    final values={'waffra_goals_v24':'[]','waffra_sms_hashes_v1':<String>[]};
    final saved=await snapshot().commit(
      expectedGeneration:0,fullFinanceSnapshot:values,
    );
    expect(saved.values.containsKey('waffra_goals_v24'),true);
    expect(saved.values.containsKey('entries'),false);
    expect(saved.values['waffra_sms_hashes_v1'],isEmpty);
  });

  test('cold reopen retains all values and monotonic generation', () async {
    await ready();
    await snapshot().initializeEmpty();
    final first=await snapshot().commit(
      expectedGeneration:0,fullFinanceSnapshot:finance(),
    );
    await vault.close();
    vault=WaffraEncryptedStore.openAt(
      File('${root.path}/full.sqlite'),key:key,
    );
    final reread=await snapshot().read();
    expect(reread.generation,1);
    expect(reread.digest,first.digest);
    expect(reread.values['entries'],first.values['entries']);
    final retry=await snapshot().initializeEmpty();
    expect(retry.generation,1);
    expect(retry.values['waffra_goals_v24'],first.values['waffra_goals_v24']);
  });

  test('stale widget or dashboard view cannot overwrite a later revision',
      () async {
    await ready();
    await snapshot().initializeEmpty();
    await snapshot().commit(
      expectedGeneration:0,fullFinanceSnapshot:finance(salary:3000),
    );
    await expectLater(snapshot().commit(
      expectedGeneration:0,fullFinanceSnapshot:finance(salary:9000),
    ),throwsA(isA<StateError>()));
    final current=await snapshot().read();
    expect(current.generation,1);
    expect(current.values['entries'],finance(salary:3000)['entries']);
  });

  test('malformed snapshot fails before SQL and original remains intact',
      () async {
    await ready();
    await snapshot().initializeEmpty();
    final first=await snapshot().commit(
      expectedGeneration:0,fullFinanceSnapshot:finance(),
    );
    for(final invalid in [
      {...finance(),'waffra_goals_v24':'not-json'},
      {...finance(),'entries':'[{"id":"a","amount":1.005}]'},
      {...finance(),'unknown-finance-key':'invalid'},
      {...finance(),'waffra_sms_hashes_v1':<int>[4]},
    ]){
      await expectLater(snapshot().commit(
        expectedGeneration:1,fullFinanceSnapshot:invalid,
      ),throwsA(anything));
    }
    final unchanged=await snapshot().read();
    expect(unchanged.generation,1);
    expect(unchanged.digest,first.digest);
  });

  test('concurrent writes with same expected revision never both succeed',
      () async {
    await ready();
    await snapshot().initializeEmpty();
    final results=await Future.wait([
      snapshot().commit(
        expectedGeneration:0,fullFinanceSnapshot:finance(salary:501),
      ).then<bool>((_)=>true,onError:(Object e,StackTrace s)=>false),
      snapshot().commit(
        expectedGeneration:0,fullFinanceSnapshot:finance(salary:502),
      ).then<bool>((_)=>true,onError:(Object e,StackTrace s)=>false),
    ]);
    expect(results.where((saved)=>saved),hasLength(1));
    expect((await snapshot().read()).generation,1);
  });

  test('table and generation checks fail closed when disabled/uninitialized',
      () async {
    await ready();
    await expectLater(snapshot(enabled:false).initializeEmpty(),
        throwsA(isA<StateError>()));
    await expectLater(snapshot().read(),throwsA(isA<Exception>()));
  });

  test('manual tampering is detected by snapshot digest validation',
      () async {
    await ready();
    await snapshot().initializeEmpty();
    await snapshot().commit(
      expectedGeneration:0,fullFinanceSnapshot:finance(),
    );
    await vault.customStatement(
      "UPDATE fresh_finance_snapshot_state SET snapshot_json='{}' "
      "WHERE singleton=1",
    );
    await expectLater(snapshot().read(),throwsA(isA<StateError>()));
  });

  test('cannot enter a fresh vault while legacy staged data exists',
      () async {
    await ready();
    await snapshot().initializeEmpty();
    await vault.stageSnapshot('another-source',const {});
    await expectLater(snapshot().read(),throwsA(isA<StateError>()));
  });
}
