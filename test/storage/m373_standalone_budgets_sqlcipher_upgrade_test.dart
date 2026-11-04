import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_fresh_finance_domain_schema.dart';
import 'package:waffra/storage/waffra_fresh_finance_domain_repository.dart';

void main() {
 late Directory directory;
 late WaffraEncryptedStore store;
 const secret='m373-disposable-only-sqlcipher-key-123456789';
 WaffraFreshFinanceDomainRepository repository()=>
  WaffraFreshFinanceDomainRepository(store:store,experimentalEnabled:true);
 Future<int> count(String table)async{
  final row=await store.customSelect('SELECT count(*) AS n FROM $table').getSingle();
  return row.read<int>('n');
 }
 setUp(()async{
  directory=await Directory.systemTemp.createTemp('waffra-m373-');
  store=WaffraEncryptedStore.openAt(File('${directory.path}/independent.db'),key:secret);
 });
 tearDown(()async{
  await store.close();
  if(await directory.exists())await directory.delete(recursive:true);
 });
 Future<void> bootstrap()async{
  await WaffraFreshEncryptedVaultBootstrap(
   store:store,experimentalEnabled:true)
    .initialize(decision:WaffraFirstRunDecision.freshCandidate);
 }
 Future<void> addExpense()async{
  await store.customStatement('INSERT INTO fresh_finance_entries '
   '(entry_id,title,category_snapshot,amount_minor,is_income,'
   'occurred_iso,receipt_count,source_json) VALUES (?,?,?, ?,0,?,0,?)',
   ['expense-1','Fuel','Other',7500,'2026-11-01T12:00:00',
    jsonEncode({'id':'expense-1','title':'Fuel','category':'Other',
      'amount':75,'income':false,'date':'2026-11-01T12:00:00'})]);
 }
 test('M373 SQLCipher standalone budget needs no category record',() async{
  await bootstrap();
  expect(WaffraFreshFinanceDomainSchema.version,2);
  expect(await count('fresh_finance_standalone_budgets'),0);
  await repository().createStandaloneBudget(budgetId:'budget:1',
    name:'Budget for fuel',limitMinor:25000,
    createdAtIso:'2026-11-01T12:00:00');
  expect(await count('fresh_finance_standalone_budgets'),1);
  expect(await count('fresh_finance_categories'),0);
  await addExpense();
  await repository().assignStandaloneExpense(
   allocationId:'link:1',budgetId:'budget:1',entryId:'expense-1',
   amountMinor:7500,assignedAtIso:'2026-11-01T12:01:00',userConfirmed:true);
  expect(await count('fresh_finance_standalone_allocations'),1);
  await repository().editStandaloneBudget(budgetId:'budget:1',
   name:'Gas',limitMinor:50000,alertPercent:85,userConfirmed:true);
  await repository().setStandaloneBudgetActive(budgetId:'budget:1',enabled:false);
  await expectLater(repository().assignStandaloneExpense(
    allocationId:'link:2',budgetId:'budget:1',entryId:'expense-1',
    amountMinor:7500,assignedAtIso:'2026-11-01T12:02:00',
    userConfirmed:true),throwsA(isA<StateError>()));
  await repository().archiveStandaloneBudget(budgetId:'budget:1',
   archivedAtIso:'2026-11-02T00:00:00',userConfirmed:true);
  expect(await count('fresh_finance_standalone_budgets'),1);
  expect(await count('fresh_finance_standalone_allocations'),1);
  expect(await count('fresh_finance_entries'),1);
  await expectLater(repository().setStandaloneBudgetActive(
   budgetId:'budget:1',enabled:true),throwsA(isA<StateError>()));
 });
 test('M373 V1-to-V2 upgrade is additive and preserves old budget links',() async{
  await bootstrap();
  await store.customStatement(
   'INSERT INTO fresh_finance_categories '
   '(category_id,name,parent_id,is_income,budget_minor,source_json) '
   'VALUES (?,?,?,0,0,?)',
   ['root','Food','',jsonEncode({'id':'root','name':'Food','budget':0})]);
  await store.customStatement(
   'INSERT INTO fresh_finance_categories '
   '(category_id,name,parent_id,is_income,budget_minor,source_json) '
   'VALUES (?,?,?,0,0,?)',
   ['child','Restaurant','root',
    jsonEncode({'id':'child','name':'Restaurant','budget':0})]);
  await repository().createNamedBudget(budgetId:'old',
   name:'Old category budget',categoryId:'child',limitMinor:10000,
   createdAtIso:'2026-11-01T12:00:00');
  await store.customStatement('DROP TABLE fresh_finance_standalone_allocations');
  await store.customStatement('DROP TABLE fresh_finance_standalone_budgets');
  await store.customStatement(
   "UPDATE fresh_finance_domain_revision SET version=1 WHERE slot='domain'");
  await store.transaction(()async{
   await WaffraFreshFinanceDomainSchema.install(store);
  });
  expect(await count('fresh_finance_named_budgets'),1);
  expect(await count('fresh_finance_standalone_budgets'),0);
  await WaffraFreshFinanceDomainSchema.requireReady(store);
 });
 test('M373 unknown/incomplete domain versions never recreate money',()async{
  await bootstrap();
  await store.customStatement('DROP TABLE fresh_finance_standalone_budgets');
  await expectLater(WaffraFreshFinanceDomainSchema.requireReady(store),
    throwsA(isA<StateError>()));
  await expectLater(store.transaction(()async{
   await WaffraFreshFinanceDomainSchema.install(store);
  }),throwsA(isA<StateError>()));
 });
}
