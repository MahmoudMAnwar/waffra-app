import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart';
import 'package:waffra/storage/waffra_migration_coordinator.dart';

void main() {
 group('M352 — installed-app upgrade must preserve legacy finance', () {
  const oldManual = <String,dynamic>{
    'id':'existing-manual-001','title':'بنزين التجربة',
    'category':'المواصلات / الوقود',
    'amount':75.25,'income':false,
    'date':'2026-10-12T10:30:00.000',
    'notes':'ملاحظة خاصة احتفظ بها',
    'receiptPath':'receipts/old-synthetic.jpg',
    'sourceType':'manual',
  };
  const oldIncome = <String,dynamic>{
    'id':'existing-income-002','title':'تحويل وارد',
    'category':'الدخل / تحويلات واردة','amount':1500,
    'income':true,'date':'2026-10-13T15:25:00.000',
    'notes':'دخل قديم',
  };
  late String oldRaw;
  setUp(() {
    oldRaw=jsonEncode([oldManual,oldIncome]);
    SharedPreferences.setMockInitialValues(<String,Object>{
      'entries':oldRaw,
      'waffra_categories_v24':jsonEncode([{
       'id':'fuel','name':'المواصلات / الوقود',
       'icon':'car','color':0xff087a54,'income':false,
       'parentId':'','budget':200,'alertPercent':80,
      }]),
      'waffra_goals_v24':jsonEncode([{
       'id':'old-goal','name':'سفر','target':10000,'saved':1200,
      }]),
      'waffra_recurring_v24':jsonEncode([{
       'id':'old-recurring','title':'إيجار','category':'سكن / إيجار',
       'amount':1000,'income':false,'day':1,'active':true,
       'startAt':'2026-10-01T00:00:00',
      }]),
      'waffra_sms_hashes_v1':<String>['existing-transaction-fingerprint'],
    });
  });

  test('old manual/income records decode without adding budgetId', () async {
   final prefs=await SharedPreferences.getInstance();
   final rows=(jsonDecode(prefs.getString('entries')!) as List)
      .map((e)=>MoneyEntry.fromJson(Map<String,dynamic>.from(e as Map)))
      .toList();
   expect(rows,hasLength(2));
   expect(rows[0].id,'existing-manual-001');
   expect(rows[0].amount,75.25);
   expect(rows[0].date,DateTime(2026,10,12,10,30));
   expect(rows[0].category,'المواصلات / الوقود');
   expect(rows[0].title,'بنزين التجربة');
   expect(rows[0].notes,'ملاحظة خاصة احتفظ بها');
   expect(rows[0].receiptPath,'receipts/old-synthetic.jpg');
   expect(rows[0].sourceType,'manual');
   expect(rows[0].budgetId,isNull);
   expect(rows[1].income,isTrue);
   expect(rows[1].budgetId,isNull);
   expect(rows[1].amount,1500);
   await prefs.reload();
   expect(prefs.getString('entries'),oldRaw,
    reason:'Upgrade reads must not overwrite any old raw finance data');
  });

  test('new budget field is strictly opt-in and cannot double-charge', () {
   final original=MoneyEntry.fromJson(oldManual);
   final income=MoneyEntry.fromJson(oldIncome);
   final budget=BudgetCategory(
    id:'fuel',name:'المواصلات / الوقود',icon:'car',
    color:0xff087a54,income:false,budget:200);
   expect(waffraNamedBudgetSpent([original,income],[budget],budget,
    DateTime(2026,10,15)),0);
   final linked=original.withBudget('fuel');
   expect(linked.toJson()..remove('budgetId'),
     original.toJson()..remove('budgetId'),
     reason:'Only the budget identifier is allowed to change');
   expect(linked.budgetId,'fuel');
   expect(original.budgetId,isNull);
   expect(waffraNamedBudgetSpent([linked,income],[budget],budget,
     DateTime(2026,10,15)),75.25);
   expect(waffraNamedBudgetSpent([linked,income],[budget],budget,
     DateTime(2026,11,1)),0,
     reason:'Old October purchase must not use November budget balance');
   expect(income.withBudget('fuel').budgetId,isNull);
   expect(linked.amount,original.amount);
  });

  test('existing goal savings, recurring rules and categories survive decode',
      () async {
   final prefs=await SharedPreferences.getInstance();
   final categories=jsonDecode(prefs.getString('waffra_categories_v24')!) as List;
   final category=BudgetCategory.fromJson(
     Map<String,dynamic>.from(categories.single as Map));
   expect(category.budget,200);
   expect(category.budgetLabel,isNull);
   final goals=jsonDecode(prefs.getString('waffra_goals_v24')!) as List;
   final goal=SavingGoal.fromJson(Map<String,dynamic>.from(goals.single as Map));
   expect(goal.saved,1200,
    reason:'An ordinary APK update must not be treated as a restore/reset');
   expect(goal.dueDate,isNull);
   final rec=jsonDecode(prefs.getString('waffra_recurring_v24')!) as List;
   final recurring=RecurringBill.fromJson(Map<String,dynamic>.from(rec.single as Map));
   expect(recurring.id,'old-recurring');
   expect(recurring.active,isTrue);
   expect(recurring.linkedGoalId,isNull);
  });

  test('staging copies old stored keys, never deletes original transactions',
      () async {
   final prefs=await SharedPreferences.getInstance();
   final copy=WaffraMigrationCoordinator.copyCurrentFinancialPreferences(prefs);
   expect(copy['entries'],oldRaw);
   expect(copy.containsKey('waffra_goals_v24'),isTrue);
   expect(copy.containsKey('waffra_recurring_v24'),isTrue);
   expect(copy.containsKey('waffra_sms_hashes_v1'),isTrue);
   expect(()=>copy['entries']='[]',throwsUnsupportedError);
   await prefs.reload();
   expect(prefs.getString('entries'),oldRaw);
  });

  test('budget review is visible, per record, cancellable, and never auto-posts',
      () {
   final home=File('lib/main.dart').readAsStringSync();
   final screen=File('lib/waffra_categories_page.part.dart').readAsStringSync();
   expect(home,contains('Future<void> reviewUnlinkedHistoricalExpenses()'));
   expect(home,contains('Future<void> assignExistingExpenseToBudget(MoneyEntry old)'));
   expect(home,contains('final pending=entries.where((e)=>!e.income&&e.budgetId==null)'));
   expect(home,contains('if(ok!=true||!mounted)return;'));
   expect(home,contains('entries[index]=entries[index].withBudget(selected.id);'));
   expect(home,contains('retroactive-opt-in-budget-link'));
   expect(home,contains('_persistModuleOrReload(WaffraFinanceRoute.transactionEdit'));
   expect(screen,contains("Key('waffra-retro-budget-review-banner')"));
   expect(screen,contains('reviewUnlinkedHistoricalExpenses()'));
   final review=home.split('Future<void> reviewUnlinkedHistoricalExpenses()')
     .last.split('Future<void> deleteNamedBudget(').first;
   expect(review,isNot(contains('entries.add(')));
   expect(review,isNot(contains('entries.clear()')));
   expect(review,isNot(contains("prefs.remove('entries'")));
  });
 });
}
