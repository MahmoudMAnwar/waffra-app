import 'dart:convert';
import 'dart:io';

import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_fresh_finance_domain_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_account_context_policies.dart';
import 'package:waffra/waffra_goal_due_policy.dart';

void main(){
 test('M665.7 verified account is debited for cash shortage, not whole due',(){
  final split=WaffraGoalDueAllocation.allocate(
   dueAmount:5000,goalSaved:2000);
  expect(split.amountMinor,500000);
  expect(split.fromGoalMinor,200000);
  expect(split.fromCurrentMinor,300000);
  expect(WaffraGoalAccountDebitPolicy.cashDebitMinor(
   totalDueMinor:split.amountMinor,
   goalWalletPaidMinor:split.fromGoalMinor),300000);
  expect(()=>WaffraGoalAccountDebitPolicy.cashDebitMinor(
   totalDueMinor:500000,goalWalletPaidMinor:500001),throwsArgumentError);
 });

 test('M665.7 SQLCipher receipt retains typed split and never writes machine notes',(){
  final source=File('lib/storage/waffra_fresh_finance_domain_repository.dart')
   .readAsStringSync();
  final method=source.substring(source.indexOf(
   '  Future<WaffraGoalDueSqlReceipt> settleLinkedGoalDue({'));
  expect(method,contains("'goalWalletPaidMinor':fromGoal"));
  expect(method,contains("'notes':''"));
  expect(method,isNot(contains("'notes':'goal_wallet_minor=")));
  expect(method,contains("'budgetId':null"));
  expect(method,contains("sourceType':'goal_due'"));
  expect(method,contains('fresh_finance_goal_due_settlements'));
  expect(method,contains('current_cash_minor'));
  expect(method,contains('alreadySettled: true'));
  expect(method,contains('fromGoal = saved < amountMinor ? saved : amountMinor'));
  expect(method,contains('fromCurrent = amountMinor - fromGoal'));
  expect(method,contains("'due-debit:\$dueKey'"));
  // Same receipt, no different second payment for an already settled ID.
  expect(method,contains('Conflicting settlement for previously paid due.'));
 });

 test('M665.7 only neutral nonbudget ledger category is selected for new linked goals',(){
  final source=File('lib/waffra_goal_recurring_actions.part.dart')
   .readAsStringSync();
  final start=source.indexOf('  }else if(linkNew){');
  final end=source.indexOf('  // Mutate both in-memory collections',start);
  final goalDue=source.substring(start,end);
  expect(goalDue,contains("c.name=='أخرى / مصروف غير مصنف'"));
  expect(goalDue,contains('if(neutral.length!=1)'));
  expect(goalDue,contains('category:neutral.single.name'));
  expect(goalDue,isNot(contains('orElse:()=>available.first')));
  expect(goalDue,contains('linkedGoalId:updated.id'));
  expect(goalDue,contains('accountId:updated.accountId'));
 });


 test('M665.7 SQLCipher integration: car due debits 3000 cash, 2000 wallet once',
 ()async{
  final dir=await Directory.systemTemp.createTemp('m665-goal-due-');
  final db=WaffraEncryptedStore.openAt(File(dir.path+'/vault.sqlite'),
   key:'m665-disposable-integration-vault-key');
  try{
   await WaffraFreshEncryptedVaultBootstrap(store:db,
    experimentalEnabled:true).initialize(
     decision:WaffraFirstRunDecision.freshCandidate);
   await WaffraAccountsSchema.install(db);
   final accounts=WaffraAccountsRepository(db:db,experimentalEnabled:true);
   await accounts.createAccount(id:'rajhi',name:'راجحي جاري',kind:'bank',
    openingMinor:1000000,createdIso:'2026-11-12T08:00:00',
    userConfirmed:true);
   final goal=<String,Object?>{
    'id':'car','name':'سيارة','saved':2000.0,'target':5000.0,
    'active':true,'accountId':'rajhi',
   };
   final due=<String,Object?>{
    'id':'car-due','title':'استحقاق سيارة','amount':5000.0,
    'income':false,'active':true,
    'category':'أخرى / مصروف غير مصنف','startAt':'2026-11-12T00:00:00',
    'day':12,'accountId':'rajhi','linkedGoalId':'car',
   };
   await db.customStatement(
    'INSERT INTO fresh_finance_goals '
    '(goal_id,name,target_minor,saved_minor,source_json) VALUES (?,?,?,?,?)',
    ['car','سيارة',500000,200000,jsonEncode(goal)]);
   await db.customStatement(
    'INSERT INTO fresh_finance_recurring '
    '(recurring_id,amount_minor,is_income,due_day,source_json) '
    'VALUES (?,?,?,?,?)',
    ['car-due',500000,0,12,jsonEncode(due)]);
   final domain=WaffraFreshFinanceDomainRepository(
    store:db,experimentalEnabled:true);
   Future<WaffraGoalDueSqlReceipt> settle(int amount)=>domain.settleLinkedGoalDue(
    goalId:'car',recurringId:'car-due',dueKey:'rec_car-due_2026_11',
    amountMinor:amount,confirmedAtIso:'2026-11-12T11:00:00',
    userConfirmed:true);
   final receipt=await settle(500000);
   expect(receipt.amountMinor,500000);
   expect(receipt.fromGoalMinor,200000);
   expect(receipt.fromCurrentMinor,300000);
   expect(receipt.alreadySettled,isFalse);
   final entry=await db.customSelect(
    "SELECT source_json FROM fresh_finance_entries "
    "WHERE entry_id='rec_car-due_2026_11'").getSingle();
   final posted=jsonDecode(entry.read<String>('source_json')) as Map;
   expect(posted['sourceType'],'goal_due');
   expect(posted['notes'],'');
   expect(posted['goalWalletPaidMinor'],200000);
   expect(posted['budgetId'],isNull);
   final goalRow=await db.customSelect(
    "SELECT saved_minor FROM fresh_finance_goals WHERE goal_id='car'"
    ).getSingle();
   expect(goalRow.read<int>('saved_minor'),0);
   await accounts.linkEntry(entryId:'rec_car-due_2026_11',
    accountId:'rajhi',linkedIso:'2026-11-12T11:00:00',
    userConfirmed:true);
   expect((await accounts.balances()).single.balanceMinor,700000,
    reason:'10,000 opening minus only 3,000 fresh cash; wallet 2,000 was reserved');
   final same=await settle(500000);
   expect(same.alreadySettled,isTrue);
   await expectLater(settle(450000),throwsStateError);
   expect((await accounts.balances()).single.balanceMinor,700000);
   final count=await db.customSelect(
    'SELECT COUNT(*) AS n FROM fresh_finance_goal_due_settlements'
    ).getSingle();
   expect(count.read<int>('n'),1);
  }finally{
   await db.close();
   if(await dir.exists())await dir.delete(recursive:true);
  }
 });
}
