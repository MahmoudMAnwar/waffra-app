import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_category_month_totals.dart';

class Row {
 const Row(this.date,this.category,this.amount,{this.income=false});
 final DateTime date;
 final String category;
 final double amount;
 final bool income;
}

void main() {
 WaffraCategoryMonthTotals summarize(List<Row> rows,DateTime month) =>
  WaffraCategoryMonthTotals.build<Row>(rows,month,
    date:(e)=>e.date,income:(e)=>e.income,
    category:(e)=>e.category,amount:(e)=>e.amount);

 test('M343 maintains category and income separation', () {
  final rows=[
   Row(DateTime(2026,11,1),'وقود',75),
   Row(DateTime(2026,11,2),'وقود',25),
   Row(DateTime(2026,11,2),'وقود',500,income:true),
   Row(DateTime(2026,11,2),'بقالة',30),
   Row(DateTime(2026,10,31),'وقود',900),
   Row(DateTime(2025,11,2),'وقود',900),
  ];
  final result=summarize(rows,DateTime(2026,11,1));
  expect(result.expenses,130);
  expect(result.amountFor(false,'وقود'),100);
  expect(result.amountFor(false,'بقالة'),30);
  expect(result.amountFor(true,'وقود'),500);
  expect(result.amountFor(true,'بقالة'),0);
 });

 test('M343 20,000 synthetic finance records aggregate exactly', () {
  final rows=List<Row>.generate(20000,(i)=>
   Row(DateTime(2026,11,1),'category-' +(i%100).toString(),1));
  final result=summarize(rows,DateTime(2026,11));
  expect(result.expenses,20000);
  expect(result.byCategory.length,100);
  expect(result.amountFor(false,'category-17'),200);
 });

 test('M343 bad money never leaks into displayed totals', () {
  expect(()=>summarize([Row(DateTime(2026,11,1),'car',double.nan)],
    DateTime(2026,11)),throwsStateError);
  expect(()=>summarize([Row(DateTime(2026,11,1),'car',-5)],
    DateTime(2026,11)),throwsStateError);
 });

 test('M343 category rename changes label, not aggregation mathematics', () {
  final prior=summarize([Row(DateTime(2026,11,1),'Fuel',75)],
    DateTime(2026,11));
  final updated=summarize([Row(DateTime(2026,11,1),'بنزين',75)],
    DateTime(2026,11));
  expect(prior.expenses,updated.expenses);
  expect(updated.amountFor(false,'بنزين'),75);
 });

 test('M343 live categories screen uses one month aggregation and lazy factories', () {
  final live=File('lib/waffra_categories_page.part.dart').readAsStringSync();
  expect(live,contains('WaffraCategoryMonthTotals.build<MoneyEntry>'));
  expect(live,contains('final groupRows=<Widget Function()>[]'));
  expect(live,contains('final pageRows=<Widget Function()>['));
  expect(live,contains('return ListView.builder('));
  expect(live,contains('itemBuilder:(context,index)=>pageRows[index]()'));
  expect(live,isNot(contains('recent.where((e)=>')));
  expect(live,isNot(contains('entries.where((e)=>e.date.year==now.year')));
  expect(live,contains('TextFormField(initialValue:categorySearch'));
 });

}
