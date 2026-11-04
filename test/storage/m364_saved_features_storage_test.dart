import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_fresh_saved_features_repository.dart';

void main() {
  late Directory dir;
  late WaffraEncryptedStore store;
  const key='waffra-m364-saved-feature-test-only-key-0001';
  const clock='2026-11-01T15:00:00';

  WaffraFreshSavedFeaturesRepository repository({bool enabled=true}) =>
      WaffraFreshSavedFeaturesRepository(store:store,
        experimentalEnabled:enabled);
  Future<int> count(String table) async =>
      (await store.customSelect('SELECT count(*) AS n FROM $table')
        .getSingle()).read<int>('n');

  setUp(() async {
    dir=await Directory.systemTemp.createTemp('waffra-m364-optional-');
    store=WaffraEncryptedStore.openAt(File('${dir.path}/data.sqlite'),key:key);
    await WaffraFreshEncryptedVaultBootstrap(
      store:store,experimentalEnabled:true,
    ).initialize(decision:WaffraFirstRunDecision.freshCandidate);
  });
  tearDown(() async {
    await store.close();
    if(await dir.exists())await dir.delete(recursive:true);
  });

  test('M364 optional saved features default to zero rows',() async {
    for(final name in const [
      'fresh_finance_project_wallets',
      'fresh_finance_project_wallet_links',
      'fresh_finance_confirmed_subscriptions',
      'fresh_finance_saved_scenarios',
      'fresh_finance_ai_threads',
      'fresh_finance_ai_messages',
      'fresh_finance_price_observations',
    ]) {
      expect(await count(name),0,reason:name);
    }
    await expectLater(repository(enabled:false).createProject(
      id:'project',title:'Home',targetMinor:10000,createdAtIso:clock,
      userConfirmed:true,
    ),throwsA(isA<StateError>()));
  });

  test('M364 scenario and subscription suggestions never silently persist',() async {
    await expectLater(repository().saveScenario(
      id:'try',kind:'before_spend',name:'مقارنة',
      values:const {'saving':250},savedAtIso:clock,userConfirmed:false,
    ),throwsA(isA<StateError>()));
    await expectLater(repository().confirmSubscription(
      id:'netflix',merchant:'Netflix',amountMinor:1999,currencyCode:'SAR',
      renewalDay:5,confirmedAtIso:clock,userConfirmed:false,
    ),throwsA(isA<StateError>()));
    expect(await count('fresh_finance_saved_scenarios'),0);
    expect(await count('fresh_finance_confirmed_subscriptions'),0);
    await repository().saveScenario(
      id:'try',kind:'before_spend',name:'مقارنة',
      values:const {'saving':250},savedAtIso:clock,userConfirmed:true,
    );
    await repository().confirmSubscription(
      id:'confirmed',merchant:'خدمة',amountMinor:1999,currencyCode:'SAR',
      renewalDay:5,confirmedAtIso:clock,userConfirmed:true,
    );
    await repository().pauseSubscription('confirmed',paused:true);
    expect(await count('fresh_finance_saved_scenarios'),1);
    expect(await count('fresh_finance_confirmed_subscriptions'),1);
    final status=await store.customSelect(
      "SELECT status FROM fresh_finance_confirmed_subscriptions "
      "WHERE subscription_id='confirmed'",
    ).getSingle();
    expect(status.read<String>('status'),'paused');
    expect(await count('fresh_finance_entries'),0,
      reason:'Subscription confirmation never posts a ledger expense.');
  });

  test('M364 project wallet is persisted but does not create fake finance',
      () async {
    await expectLater(repository().createProject(
      id:'house',title:'بيت',targetMinor:100000,
      createdAtIso:clock,userConfirmed:false,
    ),throwsA(isA<StateError>()));
    await repository().createProject(
      id:'house',title:'بيت',targetMinor:100000,
      createdAtIso:clock,userConfirmed:true,
    );
    expect(await count('fresh_finance_project_wallets'),1);
    expect(await count('fresh_finance_entries'),0);
    await expectLater(repository().linkProjectExpense(
      projectId:'house',entryId:'non-existent',allocatedMinor:500,
      userConfirmed:true,
    ),throwsA(isA<StateError>()));
    expect(await count('fresh_finance_project_wallet_links'),0);
  });

  test('M364 Ask Waffra history remains off without explicit opt-in',() async {
    await expectLater(repository().startAiThread(
      id:'t1',title:'محادثة',createdAtIso:clock,saveHistoryOptIn:false,
    ),throwsA(isA<StateError>()));
    expect(await count('fresh_finance_ai_threads'),0);
    await repository().startAiThread(
      id:'t1',title:'محادثة',createdAtIso:clock,saveHistoryOptIn:true,
    );
    await expectLater(repository().appendAiMessage(
      id:'msg',threadId:'t1',role:'user',text:'كم مصروفاتي؟',
      occurredAtIso:clock,saveHistoryOptIn:false,
    ),throwsA(isA<StateError>()));
    await repository().appendAiMessage(
      id:'msg',threadId:'t1',role:'user',text:'كم مصروفاتي؟',
      occurredAtIso:clock,saveHistoryOptIn:true,
    );
    expect(await count('fresh_finance_ai_messages'),1);
  });

  test('M364 only approved provider observations are cached',() async {
    await expectLater(repository().recordPriceObservation(
      id:'p',instrument:'gold-24',currency:'SAR',priceMicro:999,
      source:'official',observedAtIso:clock,cacheApproved:false,
    ),throwsA(isA<StateError>()));
    expect(await count('fresh_finance_price_observations'),0);
    await repository().recordPriceObservation(
      id:'p',instrument:'gold-24',currency:'SAR',priceMicro:999,
      source:'official',observedAtIso:clock,cacheApproved:true,
    );
    expect(await count('fresh_finance_price_observations'),1);
  });
}
