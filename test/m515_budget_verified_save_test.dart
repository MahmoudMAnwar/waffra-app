import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_home_transaction_capture.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_runtime_finance_route_contract.dart';

void main() {
  const source = WaffraRuntimeFinanceBackend.verifiedEncrypted;
  const categories = '[{"id":"main"}]';
  const linkedBudget = '[{"id":"budget:test","name":"Monthly","budget":1000,"assignedAccountId":"verified-account"}]';
  final fresh = <String,Object?>{
    'entries':'[]',
    'waffra_categories_v24':categories,
  };

  Map<String,Object> capture(String budget) => <String,Object>{
    'entries':'[]',
    'waffra_categories_v24':categories,
    'waffra_named_budgets_v1':budget,
    'waffra_goals_v24':'[]',
    'waffra_recurring_v24':'[]',
    'waffra_challenges_v1':'[]',
    'waffra_deleted_categories_v1':'[]',
    'waffra_deleted_goals_v1':'[]',
    'waffra_deleted_recurring_v1':'[]',
    'waffra_recurring_postponed_v1':'{}',
    'waffra_monthly_budget_v1':0.0,
    'waffra_monthly_budget_enabled_v1':false,
    'waffra_learned_merchants_v1':'{}',
  };

  test('M515 first account-linked budget retains the only edited finance projection',(){
    final data=capture(linkedBudget);
    WaffraHomeTransactionCapture.narrowVerifiedModuleEdit(
      route:WaffraFinanceRoute.challengeAndBudgetUpdate,
      source:source,snapshot:data,witnessedValues:fresh);
    expect(data['waffra_named_budgets_v1'],linkedBudget);
    expect(data.keys.toSet(),{
      'waffra_named_budgets_v1',
      'waffra_categories_v24',
      'waffra_challenges_v1',
      'waffra_monthly_budget_v1',
      'waffra_monthly_budget_enabled_v1',
    });
    expect(data.containsKey('entries'),false);
  });

  test('M515 unchanged previously saved budgets remain immutable while adding another',(){
    const previous='[{"id":"budget:old","budget":250}]';
    const updated='[{"id":"budget:old","budget":250},{"id":"budget:new","budget":1000,"assignedAccountId":"account-a"}]';
    final data=capture(updated);
    WaffraHomeTransactionCapture.narrowVerifiedModuleEdit(
      route:WaffraFinanceRoute.challengeAndBudgetUpdate,
      source:source,snapshot:data,
      witnessedValues:{...fresh,'waffra_named_budgets_v1':previous});
    expect(data['waffra_named_budgets_v1'],updated);
  });

  test('M515 budget edit rejects unrelated financial changes',(){
    final data=capture(linkedBudget)..['waffra_goals_v24']='[{"id":"unexpected-goal"}]';
    expect(()=>WaffraHomeTransactionCapture.narrowVerifiedModuleEdit(
      route:WaffraFinanceRoute.challengeAndBudgetUpdate,
      source:source,snapshot:data,witnessedValues:fresh),throwsStateError);
  });

  test('M515 refused budget edit cannot silently overwrite ledger',(){
    final data=capture(linkedBudget)..['entries']='[{"id":"new-money"}]';
    expect(()=>WaffraHomeTransactionCapture.narrowVerifiedModuleEdit(
      route:WaffraFinanceRoute.challengeAndBudgetUpdate,
      source:source,snapshot:data,witnessedValues:fresh),throwsStateError);
  });

  test('M515 authority expressly allows named budgets, never ledger or accounts',(){
    final auth=File('lib/storage/waffra_verified_finance_authority.dart')
      .readAsStringSync();
    final section=auth.split('WaffraFinanceRoute.challengeAndBudgetUpdate => <String>{').last
      .split('WaffraFinanceRoute.recurringPostingAndPostponement => <String>{').first;
    expect(section,contains("'waffra_named_budgets_v1'"));
    expect(section,isNot(contains("'entries'")));
    expect(section,isNot(contains("'waffra_accounts_v1'")));
  });
}
