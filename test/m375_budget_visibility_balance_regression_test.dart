import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';

void main() {
  test('M375 no budget picker with empty, paused or archived budgets', () {
    final active=WaffraNamedBudget(
      id:'budget:food',name:'Food',budget:600,alertPercent:80);
    expect(waffraHasSelectableBudget(<WaffraNamedBudget>[]),isFalse);
    expect(waffraHasSelectableBudget([active.copy(budgetActive:false)]),isFalse);
    expect(waffraHasSelectableBudget([active.copy(deleted:true)]),isFalse);
    expect(waffraHasSelectableBudget([active]),isTrue);
    expect(waffraHasSelectableBudget([
      active.copy(deleted:true),active.copy(budgetActive:false),
      WaffraNamedBudget(id:'budget:car',name:'Car',budget:350),
    ]),isTrue);
  });

  test('M375 all recorded income contributes to current balance', () {
    MoneyEntry entry(String id,double amount,bool income)=>MoneyEntry(
      id:id,title:id,category:income?'Salary':'Groceries',
      amount:amount,income:income,date:DateTime(2026,11,2));
    final ledger=[
      entry('income-one',5000,true),
      entry('expense-one',1000,false),
      entry('income-two',3000,true),
      entry('expense-two',500,false),
    ];
    final goal=SavingGoal(id:'goal',name:'Rent',target:5000,saved:900);
    expect(waffraAvailableCash(ledger,[goal]),6500);
    expect(waffraAvailableCash(ledger.reversed,[goal]),6500,
      reason:'The latest income must not replace prior income.');
    final restored=ledger.map((e)=>MoneyEntry.fromJson(e.toJson())).toList();
    expect(waffraAvailableCash(restored,[goal]),6500,
      reason:'Round-tripping financial records must preserve all incomes.');
    expect(restored.where((e)=>e.income).length,2);
    expect(restored.every((e)=>e.budgetId==null),isTrue);
    expect(waffraAvailableCash([
      ...restored,
      MoneyEntry(id:'goal-due',title:'Goal due',category:'Housing',
        amount:300,income:false,date:DateTime(2026,11,2),
        sourceType:'goal_due',goalWalletPaidMinor:20000),
    ],[goal]),6400,
      reason:'Only the non-wallet share of a goal settlement debits cash.');
  });

  test('M375 all entry paths suppress linking until an active budget exists', () {
    final app=File('lib/main.dart').readAsStringSync();
    final categories=File('lib/waffra_categories_page.part.dart')
      .readAsStringSync();
    expect(app,contains('if(!income&&waffraHasSelectableBudget(namedBudgets))...['),
      reason:'Manual, bank and OCR share the transaction editor.');
    expect(app,contains('if(!candidates.any((e)=>!e.income)||choices.isEmpty)return assigned;'),
      reason:'Bank batch/individual import must bypass absent budget UI.');
    expect(app,contains('if(initial==null&&!income&&'),
      reason:'New expenses choose an existing budget when one exists.');
    expect(app,contains('assigned[pair.key]==null'),
      reason:'Bank SMS review must require selection only when a budget exists.');
    expect(categories,contains('unassignedExpenseCount>0&&waffraHasSelectableBudget(namedBudgets)'),
      reason:'Older unassigned expenses should surface after budget creation.');
    expect(app,contains('showBudgetInfo:entry.budgetId!=null||waffraHasSelectableBudget(namedBudgets)'),
      reason:'Details must not nag users about budgets that do not exist.');
  });
}
