import 'dart:io';

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
}
