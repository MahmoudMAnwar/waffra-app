import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_finance_domain_legacy_importer.dart';

void main() {
  late Directory tmp;
  late WaffraEncryptedStore db;
  const secret='m364-migration-disposable-only-secret-32';
  const now='2026-11-01T16:30:00';

  Future<int> count(String t)async =>
    (await db.customSelect('SELECT count(*) AS n FROM $t').getSingle())
      .read<int>('n');

  Future<void> addCategory(String id,{
    double budget=0,String parent='',bool enabled=true,
  }) => db.customStatement(
    'INSERT INTO fresh_finance_categories '
    '(category_id,name,parent_id,is_income,budget_minor,source_json) '
    'VALUES (?,?,?,0,?,?)',
    [id,id,parent,(budget*100).round(),jsonEncode({
      'id':id,'name':id,'income':false,'parentId':parent,
      'budget':budget,'budgetLabel':'ميزانية $id',
      'budgetActive':enabled,'alertPercent':80,
    })],
  );

  Future<void> addEntry(String id,{String? budgetId,int amount=1250}) =>
    db.customStatement(
      'INSERT INTO fresh_finance_entries '
      '(entry_id,title,category_snapshot,amount_minor,is_income,'
      'occurred_iso,source_json) VALUES (?,?,?,?,0,?,?)',
      [id,'شراء','fuel',amount,now,jsonEncode({
        'id':id,'title':'شراء','category':'fuel','income':false,
        'amount':amount/100,'date':now,
        if(budgetId!=null)'budgetId':budgetId,
      })],
    );

  Future<void> addGoal(String id,{double saved=125}) =>
    db.customStatement(
      'INSERT INTO fresh_finance_goals '
      '(goal_id,name,target_minor,saved_minor,source_json) '
      'VALUES (?,?,?,?,?)',
      [id,id,30000,(saved*100).round(),jsonEncode({
        'id':id,'name':id,'target':300.0,'saved':saved,
      })],
    );

  WaffraFinanceDomainLegacyImporter importer({bool enabled=true}) =>
    WaffraFinanceDomainLegacyImporter(
      store:db,experimentalEnabled:enabled,
    );

  setUp(() async {
    tmp=await Directory.systemTemp.createTemp('m364-legacy-import-');
    db=WaffraEncryptedStore.openAt(File('${tmp.path}/db.sqlite'),key:secret);
    await WaffraFreshEncryptedVaultBootstrap(
      store:db,experimentalEnabled:true,
    ).initialize(decision:WaffraFirstRunDecision.freshCandidate);
  });

  tearDown(() async {
    await db.close();
    if(await tmp.exists())await tmp.delete(recursive:true);
  });

  test('M364 explicit migration preserves named budgets, old links, openings',
      () async {
    await addCategory('car');
    await addCategory('fuel',parent:'car',budget:250,enabled:false);
    await addEntry('old-sms',budgetId:'fuel');
    await addEntry('unassigned');
    await addGoal('g1',saved:145.75);
    final first=await importer().importCapturedDomain(
      explicitlyAuthorized:true,importedAtIso:now,
    );
    expect(first.namedBudgetsCreated,1);
    expect(first.budgetLinksCreated,1);
    expect(first.goalOpeningsCreated,1);
    expect(first.unresolvedBudgetLinks,0);
    expect(await count('fresh_finance_named_budgets'),1);
    expect(await count('fresh_finance_budget_allocations'),1);
    expect(await count('fresh_finance_goal_opening_balances'),1);
    expect(await count('fresh_finance_goal_wallet_movements'),0,
      reason:'Historical goal.saved is not a fabricated deposit timeline.');
    final budget=await db.customSelect(
      "SELECT is_active,monthly_limit_minor FROM fresh_finance_named_budgets "
      "WHERE budget_id='legacy-budget:fuel'",
    ).getSingle();
    expect(budget.read<int>('is_active'),0);
    expect(budget.read<int>('monthly_limit_minor'),25000);
    final duplicate=await importer().importCapturedDomain(
      explicitlyAuthorized:true,importedAtIso:now,
    );
    expect(duplicate.namedBudgetsCreated,0);
    expect(duplicate.budgetLinksCreated,0);
    expect(duplicate.goalOpeningsCreated,0);
    expect(await count('fresh_finance_budget_allocations'),1);
  });

  test('M364 orphan old links remain in source and are never guessed',
      () async {
    await addEntry('orphan',budgetId:'deleted-category');
    final result=await importer().importCapturedDomain(
      explicitlyAuthorized:true,importedAtIso:now,
    );
    expect(result.unresolvedBudgetLinks,1);
    expect(await count('fresh_finance_budget_allocations'),0);
    final kept=await db.customSelect(
      "SELECT source_json FROM fresh_finance_entries WHERE entry_id='orphan'",
    ).getSingle();
    expect((jsonDecode(kept.read<String>('source_json')) as Map)['budgetId'],
      'deleted-category');
  });

  test('M364 no user authorization and malformed finance fail closed',
      () async {
    await addCategory('fuel',budget:100);
    await addGoal('g1');
    await expectLater(importer().importCapturedDomain(
      explicitlyAuthorized:false,importedAtIso:now,
    ),throwsA(isA<StateError>()));
    expect(await count('fresh_finance_named_budgets'),0);
    await db.customStatement(
      "UPDATE fresh_finance_goals SET saved_minor=999 WHERE goal_id='g1'",
    );
    await expectLater(importer().importCapturedDomain(
      explicitlyAuthorized:true,importedAtIso:now,
    ),throwsA(isA<StateError>()));
    expect(await count('fresh_finance_named_budgets'),0,
      reason:'Migration rolled back budget insertion on goal mismatch.');
    expect(await count('fresh_finance_goal_opening_balances'),0);
  });
}
