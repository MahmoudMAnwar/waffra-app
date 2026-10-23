import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';

void main() {
  final restaurants=BudgetCategory(
    id:'expense_root',name:'مطاعم وكافيهات',icon:'restaurant',
    color:0xFF087A54,income:false);
  final popular=BudgetCategory(
    id:'expense_leaf',name:'مطاعم وكافيهات / مطاعم شعبية',icon:'restaurant',
    color:0xFF087A54,income:false,parentId:'expense_root');
  final coffee=BudgetCategory(
    id:'expense_leaf2',name:'مطاعم وكافيهات / كافيهات',icon:'coffee',
    color:0xFF087A54,income:false,parentId:'expense_root');
  final salary=BudgetCategory(
    id:'income_root',name:'الرواتب',icon:'salary',
    color:0xFF087A54,income:true);
  final monthlySalary=BudgetCategory(
    id:'income_leaf',name:'الرواتب / راتب أساسي',icon:'salary',
    color:0xFF087A54,income:true,parentId:'income_root');
  final orphan=BudgetCategory(
    id:'orphan',name:'قسم محذوف / فرعي',icon:'category',
    color:0xFF087A54,income:false,parentId:'removed_parent');
  final fixture=<BudgetCategory>[restaurants,popular,coffee,salary,monthlySalary,orphan];

  test('Manual main category choices match income or expenses', () {
    expect(waffraManualCategoryParents(fixture,false).map((c)=>c.id),['expense_root']);
    expect(waffraManualCategoryParents(fixture,true).map((c)=>c.id),['income_root']);
  });

  test('Subcategory options depend on parent and transaction type', () {
    expect(waffraManualCategoryChildren(fixture,false,'expense_root').map((c)=>c.id),
      ['expense_leaf','expense_leaf2']);
    expect(waffraManualCategoryChildren(fixture,false,'income_root'),isEmpty);
    expect(waffraManualCategoryChildren(fixture,true,'income_root').map((c)=>c.id),
      ['income_leaf']);
    expect(waffraManualCategoryChildren(fixture,false,null),isEmpty);
  });

  test('Saving manual entries rejects root, orphan and other parent or type', () {
    expect(waffraCanAssignManualCategory(fixture,false,'expense_root',popular.name),isTrue);
    expect(waffraCanAssignManualCategory(fixture,true,'income_root',monthlySalary.name),isTrue);
    expect(waffraCanAssignManualCategory(fixture,false,'expense_root',restaurants.name),isFalse);
    expect(waffraCanAssignManualCategory(fixture,false,'income_root',monthlySalary.name),isFalse);
    expect(waffraCanAssignManualCategory(fixture,true,'expense_root',popular.name),isFalse);
    expect(waffraCanAssignManualCategory(fixture,false,'removed_parent',orphan.name),isFalse);
    expect(waffraCanAssignManualCategory(fixture,false,null,popular.name),isFalse);
    expect(waffraCanAssignManualCategory(fixture,false,'expense_root',monthlySalary.name),isFalse);
  });

  test('Manual sheet uses two searchable selections and leaf validation', () {
    final app=File('lib/main.dart').readAsStringSync();
    final start=app.indexOf(' Future<void> entrySheet(');
    final end=app.indexOf(' Future<String?> chooseTransactionCategory(',start);
    expect(start,greaterThanOrEqualTo(0));
    expect(end,greaterThan(start));
    final sheet=app.substring(start,end);
    expect(sheet,contains("'Main category *':'القسم الرئيسي *'"));
    expect(sheet,contains("'Subcategory *':'القسم الفرعي *'"));
    expect(sheet,contains('mainCategories,'));
    expect(sheet,contains('subcategories,'));
    expect(sheet,contains('leafLabels:true'));
    expect(sheet,contains('parentId:mainId'));
    expect(sheet,contains('waffraCanAssignManualCategory(categories,'));
    expect(sheet,contains('if(sms)'));
  });

  test('Widget hides yellow duplicate copy icon without weakening detection', () {
    final widget=File('lib/waffra_widget_capture.part.dart').readAsStringSync();
    expect(widget,isNot(contains('trailing:record.duplicate?const Icon(Icons.copy')));
    expect(widget,contains('_knownHashes.contains(hash)||!inPaste.add(hash)'));
    expect(widget,contains('(!r.duplicate||_allowDuplicates)'));
    expect(widget,contains('السماح بإضافة الرسائل المكررة'));
  });
}
