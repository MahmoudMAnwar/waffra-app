import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/storage/waffra_authoritative_widget_balance.dart';

void main() {
  MoneyEntry expense(String id, double amount, {int fromWalletMinor=0}) =>
      MoneyEntry(
        id:id,title:'Expense $id',category:'Housing',amount:amount,
        income:false,date:DateTime.utc(2026,11,1),
        sourceType:fromWalletMinor>0?'goal_due':'manual',
        goalWalletPaidMinor:fromWalletMinor,
      );

  test('M371 screenshot: creating/funding 9000 goals cannot deduct 9000 cash',
      () {
    final expenses=<MoneyEntry>[
      expense('fuel',75),expense('restaurant',1000),
      expense('transfer',60),
    ];
    final goals=<SavingGoal>[
      SavingGoal(id:'rent',name:'Rent',target:12000,saved:9000),
    ];
    // No income was recorded, so genuine expenses still show -1135.
    // The previous bug showed -10135 by subtracting goals savings again.
    expect(waffraGoalWalletBalance(goals),9000);
    expect(waffraAvailableCash(expenses,goals),-1135);
    expect(waffraAvailableCash(expenses,[
      goals.single.copy(saved:0),
    ]),-1135);
    expect(waffraAvailableCash(expenses,[
      goals.single.copy(saved:12000),
    ]),-1135);
  });

  test('M371 full goal-wallet payment does not charge current cash again',
      () {
    final savings=[SavingGoal(
      id:'trip',name:'Trip',target:500,saved:300)];
    final ledger=<MoneyEntry>[
      MoneyEntry(id:'income',title:'Salary',category:'Salary',amount:1000,
        income:true,date:DateTime.utc(2026,11,1)),
      expense('goal-due',200,fromWalletMinor:20000),
    ];
    final after=[savings.single.copy(saved:100)];
    expect(waffraAvailableCash(ledger,savings),1000);
    expect(waffraAvailableCash(ledger,after),1000);
    expect(WaffraAuthoritativeWidgetBalance.netHalalas(
      jsonEncode(ledger.map((e)=>e.toJson()).toList())),100000);
    final due=MoneyEntry.fromJson(ledger.last.toJson());
    expect(due.goalWalletPaidMinor,20000);
    expect(due.withCategory('Other').goalWalletPaidMinor,20000);
    expect(due.withBudget('fuel').goalWalletPaidMinor,20000);
  });

  test('M371 partially funded due charges cash for shortfall exactly once',
      () {
    final ledger=<MoneyEntry>[
      MoneyEntry(id:'income',title:'Salary',category:'Salary',amount:1000,
        income:true,date:DateTime.utc(2026,11,1)),
      expense('goal-due',250,fromWalletMinor:20000),
    ];
    expect(waffraAvailableCash(ledger,[
      SavingGoal(id:'g',name:'Goal',target:500,saved:0),
    ]),950);
    expect(WaffraAuthoritativeWidgetBalance.netHalalas(
      jsonEncode(ledger.map((e)=>e.toJson()).toList())),95000);
    expect(WaffraAuthoritativeWidgetBalance.netHalalas(
      jsonEncode([expense('other',120).toJson()])), -12000);
  });

  test('M371 malformed goal allocation is rejected by the Widget',
      () {
    Map<String,Object?> entry(String type, Object minor)=> {
      'id':'goal-due','title':'Goal','amount':75.0,'income':false,
      'sourceType':type,'goalWalletPaidMinor':minor,
    };
    for(final bad in [
      entry('manual',100),
      entry('goal_due',-1),
      entry('goal_due',7501),
      entry('goal_due','2000'),
      {...entry('goal_due',100),'income':true},
    ]) {
      expect(()=>WaffraAuthoritativeWidgetBalance.netHalalas(
        jsonEncode([bad])),throwsStateError);
    }
  });

  test('M371 budgets open in bounded Android sheet, not nested lazy expansion',
      () {
    final source=File('lib/waffra_budget_directory.part.dart').readAsStringSync();
    expect(source,contains('showModalBottomSheet<void>('));
    expect(source,contains('DraggableScrollableSheet('));
    expect(source,contains('controller:scroll'));
    expect(source,contains('showBudgetsDirectorySheet'));
    expect(source,contains("'waffra-my-budgets-entry'"));
    expect(source,contains("'waffra-budget-directory-search'"));
    expect(source,contains("'waffra-saved-budget-'"));
    expect(source,isNot(contains('LayoutBuilder(builder:(ctx,box){')));
    // Reassignments and history are never altered by a screen refactor.
    expect(source,contains('editBudgetForCategory(b)'));
    expect(source,contains('setNamedBudgetActive(b,enabled)'));
    expect(source,contains('deleteNamedBudget(b)'));
  });

  test('M371 goal creation cannot post an expense or negative cash debit',
      () {
    final source=File('lib/main.dart').readAsStringSync();
    expect(source,contains('target:noTarget?0.0:n!,saved:0,dueDate:selectedDeadline'));
    expect(source,contains('setState(()=>goals.add(g))'));
    expect(source,contains('operation:\'goal-create\''));
    expect(source,contains('balance:waffraAvailableCash(entries,goals)'));
    expect(source,contains('goalWalletPaidMinor:allocation.fromGoalMinor'));
    expect(source,isNot(contains('inc-exp-waffraGoalWalletBalance(goals)')));
    expect(source,contains('إضافة الادخار لن تخصم أي مبلغ من الرصيد الحالي'));
  });
}
