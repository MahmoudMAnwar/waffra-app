import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_category_rankings.dart';

class Group {
 const Group(this.id,this.name,this.income,this.amount);
 final String id,name;
 final bool income;
 final double amount;
}

List<String> rank(List<Group> rows,String mode) =>
 waffraRankCategoryRoots<Group>(rows,mode:mode,
    label:(e)=>e.name,isIncome:(e)=>e.income,
    monthlyTotal:(e)=>e.amount).map((e)=>e.id).toList();

void main(){
 const sample=[
  Group('shops','Shopping',false,750),
  Group('salary','Salary',true,12000),
  Group('rent','Rent',false,2300),
  Group('bonus','Bonus',true,500),
  Group('fuel','Fuel',false,100),
 ];
 test('M351 highest monthly income puts income groups first',(){
  expect(rank(sample,'income'),['salary','bonus','fuel','rent','shops']);
 });
 test('M351 highest monthly expense puts expense groups first',(){
  expect(rank(sample,'spent'),['rent','shops','fuel','bonus','salary']);
 });
 test('M351 default preserves catalog order and alphabetical sorts labels',(){
  expect(rank(sample,'default'),['shops','salary','rent','bonus','fuel']);
  expect(rank(sample,'alpha'),['bonus','fuel','rent','salary','shops']);
 });
 test('M351 equal totals have stable alphabetical and original ties',(){
  const ties=[
   Group('one','Same',false,500),
   Group('two','Same',false,500),
   Group('three','Different',false,500),
  ];
  expect(rank(ties,'spent'),['three','one','two']);
 });
 test('M351 rankings leave finance records and amounts unchanged',(){
  final mutable=sample.toList();
  final ranked=rank(mutable,'income');
  expect(ranked.first,'salary');
  expect(mutable.map((r)=>r.id).toList(),sample.map((r)=>r.id).toList());
  expect(mutable.map((r)=>r.amount).toList(),
    [750,12000,2300,500,100]);
 });
 test('M351 malformed amounts and unsupported ranking reject safely',(){
  expect(()=>rank([const Group('n','NaN',true,double.nan)],'income'),
    throwsStateError);
  expect(()=>rank(sample,'unknown'),throwsArgumentError);
 });
 test('M351 category UI keeps filters compact and adds actual dropdowns',(){
  final ui=File('lib/waffra_categories_page.part.dart').readAsStringSync();
  expect(ui,contains("Key('waffra-category-filter-accordion')"));
  expect(ui,contains("PageStorageKey<String>('waffra-category-filter-dropdown')"));
  expect(ui,contains('ExpansionTile('));
  expect(ui,contains("initiallyExpanded:categoryFiltersOpen"));
  expect(ui,contains("DropdownButtonFormField<String>("));
  expect(ui,contains("key:ValueKey('waffra-category-type-'"));
  expect(ui,isNot(contains("key:ValueKey('waffra-category-budget-'")));
  expect(ui,contains("key:ValueKey('waffra-category-sort-'"));
  expect(ui,contains("categoryMineOnly=v"));
  expect(ui,contains('monthlyTotals[(root.income,root.name)]'));
  // M356 keeps M351's semantics through the shared single-pass category summary.
  expect(ui,contains('WaffraCategoryMonthTotals.build<MoneyEntry>'));
  expect(ui,contains('final expenseTotal=monthly.expenses;'));
  expect(ui,contains('onRow:(e){if(!e.income&&e.budgetId==null)unassignedExpenseCount++;}'));
  expect(ui,isNot(contains("Wrap(spacing:7,runSpacing:7,children:[\n    _filterChip")));
 });
}
