import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/storage/legacy_snapshot_preflight.dart';

void main() {
  test('M373 independent budget saves without any category ID', () {
    final saved=WaffraNamedBudget(id:'budget:1',name:'ميزانية البنزين',
      budget:200,alertPercent:80);
    final raw=saved.toJson();
    expect(raw['id'],'budget:1');
    expect(raw['name'],'ميزانية البنزين');
    expect(raw['parentId'],'');
    expect(raw, isNot(contains('categoryId')));
    expect(raw, isNot(contains('subcategoryId')));
    expect(saved.budget,200);
    final decoded=WaffraNamedBudget.fromJson(raw);
    expect(decoded.name,saved.name);
    expect(decoded.budgetActive,isTrue);
    final renamed=decoded.copy(name:'مصاريف السيارة',budget:350);
    expect(renamed.id,decoded.id);
    expect(renamed.name,'مصاريف السيارة');
    expect(renamed.budget,350);
    expect(renamed.budgetActive,isTrue);
  });

  test('M373 paused/deleted budgets retain IDs and historical allocations', () {
    final b=WaffraNamedBudget(id:'budget:old',name:'البيت',budget:900);
    final paused=b.copy(budgetActive:false);
    final archived=paused.copy(deleted:true);
    expect(archived.id,b.id);
    expect(archived.budget,900);
    expect(archived.deleted,isTrue);
    expect(archived.budgetActive,isFalse);
    final old=MoneyEntry(id:'old-expense',title:'Electricity',category:'فواتير / كهرباء',
     amount:65,income:false,date:DateTime(2026,11,1),budgetId:b.id);
    expect(old.withBudget(null).category,old.category);
    expect(old.toJson()['budgetId'],archived.id);
    expect(archived.toJson()['deleted'],true);
  });

  test('M373 legacy budget ID migrates without relinking ledger records', () {
    final original=BudgetCategory(id:'legacy-id',name:'الأكل',icon:'restaurant',
      color:0xff087a54,income:false,budget:300,budgetLabel:'ميزانية الأكل');
    final migrated=WaffraNamedBudget.fromLegacy(original);
    expect(migrated.id,'legacy-id');
    expect(migrated.name,'ميزانية الأكل');
    expect(original.id,migrated.id);
    final transaction=MoneyEntry(id:'t1',title:'Dinner',
      category:'مطاعم وكافيهات / مطاعم شعبية',amount:70,
      income:false,date:DateTime(2026,11,1),budgetId:'legacy-id');
    expect(transaction.budgetId,migrated.id);
    expect(WaffraNamedBudget.fromJson(migrated.toJson()).id,transaction.budgetId);
  });

  test('M373 malformed standalone financial budgets fail closed', () {
    final budget=WaffraNamedBudget(id:'budget:1',name:'Bills',budget:700);
    final ok=WaffraLegacyPreflight.inspect({
      'waffra_named_budgets_v1':jsonEncode([budget.toJson()]),
    });
    expect(ok.canStage,isTrue);
    for(final broken in [
      {...budget.toJson(),'budget':-1},
      {...budget.toJson(),'budget':0},
      {...budget.toJson(),'budget':0.0001},
      {...budget.toJson(),'name':''},
      {...budget.toJson(),'parentId':'secret-category'},
      {...budget.toJson(),'budgetActive':'false'},
      {...budget.toJson(),'alertPercent':200},
    ]) {
      final result=WaffraLegacyPreflight.inspect({
        'waffra_named_budgets_v1':jsonEncode([broken]),
      });
      expect(result.canStage,isFalse,reason:broken.toString());
    }
  });

  test('M373 all money flows use independent budget catalogue', () {
    final app=File('lib/main.dart').readAsStringSync();
    final directory=File('lib/waffra_budget_directory.part.dart').readAsStringSync();
    expect(app,contains("'waffra_named_budgets_v1':jsonEncode("));
    expect(app,contains("financeView.getString('waffra_named_budgets_v1')"));
    expect(app,contains("view.getString('waffra_named_budgets_v1')"));
    expect(app,contains("namedBudgets.add(WaffraNamedBudget("));
    expect(app,contains("WaffraNamedBudget.fromLegacy(c)"));
    expect(app,contains("'namedBudgets':listValue('waffra_named_budgets_v1'"));
    expect(app,contains("'waffra_named_budgets_v1':'[]'"));
    expect(app,contains("operation:'standalone-budget-create'"));
    expect(app,contains("operation:'standalone-budget-soft-delete'"));
    expect(app,contains("operation:'standalone-budget-toggle'"));
    expect(app,contains("operation:'standalone-budget-edit'"));
    expect(app,contains("reviewSmsBudgetLinks(additions)"));
    expect(directory,contains("saved=namedBudgets.where((b)=>!b.deleted)"));
    final create=app.split('Future<String?> chooseBudgetCategory(').last
     .split('void refreshFromBudgetDirectory()').first;
    expect(create,isNot(contains('Choose main expense category')));
    expect(create,isNot(contains('Choose subcategory')));
    expect(create,isNot(contains('parentId=item.id')));
  });
}
