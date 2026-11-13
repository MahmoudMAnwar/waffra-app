import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart' show MoneyEntry,WaffraFinancePeriodIndex;

MoneyEntry entry(String id,int year,int month,int day,{
 bool income=false,double amount=100,
})=>MoneyEntry(
 id:id,title:'Verified $id',category:'اختبار',
 amount:amount,income:income,
 date:DateTime(year,month,day,12),sourceType:'manual');

void main(){
 test('M684 year and month read exact historical source IDs and order',(){
  final rows=[
   entry('nov-expense',2026,11,5),
   entry('oct-legacy',2026,10,6),
   entry('prior-year',2025,12,8,income:true),
   entry('nov-income',2026,11,18,income:true),
   entry('future',2026,12,2),
  ];
  final read=WaffraFinancePeriodIndex(rows);
  List<String> ids(Iterable<MoneyEntry> data)=>data.map((e)=>e.id).toList();
  expect(ids(read.month(2026,11)),['nov-expense','nov-income']);
  expect(ids(read.month(2026,10)),['oct-legacy']);
  expect(read.month(2026,1),isEmpty);
  expect(ids(read.year(2025)),['prior-year']);
  expect(ids(read.year(2026)),
   ['nov-expense','oct-legacy','nov-income','future']);
  expect(read.years.toSet(),{2025,2026});
  expect(()=>read.month(2026,13),throwsArgumentError);
  expect(rows.length,5);
 });

 test('M684 selected-account ID lookup retains old entries, ordering and excludes unassigned',(){
  final source=[
   entry('unassigned',2026,11,5),
   entry('linked-october',2026,10,6),
   entry('other-account',2026,11,5),
   entry('linked-november',2026,11,18),
  ];
  final read=WaffraFinancePeriodIndex(source);
  expect(read.byIds({'linked-november','linked-october'})
   .map((e)=>e.id).toList(),['linked-october','linked-november']);
  expect(read.byIds({'missing-account'}),isEmpty);
  expect(read.byIds({}),isEmpty);
  expect(source.length,4);
 });

 test('M684 multi-month forecast never repeats money or changes source order',(){
  final rows=[
   entry('dec',2025,12,1),
   entry('jan',2026,1,1,income:true),
   entry('nov',2026,11,4),
   entry('old',2024,10,6),
   entry('oct',2026,10,5,income:true),
  ];
  final read=WaffraFinancePeriodIndex(rows);
  final recent=read.months([
   DateTime(2026,10),DateTime(2025,12),DateTime(2026,10),
   DateTime(2026,11),
  ]);
  expect(recent.map((e)=>e.id).toList(),['dec','nov','oct']);
  expect(recent.fold<double>(0,(s,e)=>s+e.amount),300);
  expect(read.before(DateTime(2026,1)).map((e)=>e.id).toList(),
   ['dec','old']);
 });

 test('M684 90-day range preserves exact time boundaries and excludes future',(){
  final from=DateTime(2026,8,15,12);
  final until=DateTime(2026,11,13,12);
  final read=WaffraFinancePeriodIndex([
   entry('start',2026,8,15),entry('inside',2026,9,1),
   entry('end',2026,11,13),entry('future',2026,12,1),
   entry('old',2026,7,1),
  ]);
  expect(read.between(from,until,startInclusive:false,endInclusive:true)
    .map((e)=>e.id).toList(),['inside','end']);
  expect(read.between(from,until,startInclusive:true)
    .map((e)=>e.id).toList(),['start','inside']);
  expect(read.between(until,from),isEmpty);
 });

 test('M684 index is read-only snapshot; rebuild after verified ledger edit',(){
  final rows=[entry('one',2026,10,1)];
  final before=WaffraFinancePeriodIndex(rows);
  rows[0]=entry('one',2026,11,1);
  rows.add(entry('two',2026,11,2));
  expect(before.month(2026,10).map((e)=>e.id).toList(),['one']);
  expect(before.month(2026,11),isEmpty);
  final after=WaffraFinancePeriodIndex(rows);
  expect(after.month(2026,10),isEmpty);
  expect(after.month(2026,11).map((e)=>e.id).toList(),
   ['one','two']);
  expect(()=>after.month(2026,11).clear(),throwsUnsupportedError);
 });

 test('M684 shared period reads are wired to Home, Budgets, Analytics and forecast',(){
  final s=File('lib/main.dart').readAsStringSync();
  expect(s,contains("part 'waffra_finance_period_index.part.dart';"));
  expect(s,contains('_m684ScopedMonthEntries(now.year,now.month)'));
  expect(s,contains('_m684ScopedMonthEntries(\n   viewedMonth.year,viewedMonth.month)'));
  expect(s,contains('_m684Periods.year(year):_m684Periods.month(year,month)'));
  expect(s,contains('final history=_m684Periods.months(used);'));
  expect(s,contains('final recent=_m684Periods.between('));
  expect(s,contains('final previousRows=_m684Periods.month('));
  expect(s,contains('_m684Periods.before(monthStart)'));
  expect(s,contains('final ids=_m684ScopedEntryIds;'));
  expect(s,contains('return _m684Periods.byIds(ids);'));
  // No persistent app-authority writes or duplicate financial ledger postings.
  final index=File('lib/waffra_finance_period_index.part.dart')
   .readAsStringSync();
  expect(index,isNot(contains('.customStatement(')));
  expect(index,isNot(contains('INSERT INTO')));
  expect(index,isNot(contains('UPDATE ')));
  expect(index,isNot(contains('DELETE FROM')));
 });

 test('M684 index invalidation covers insert/edit/delete, restore and reset',(){
  final s=File('lib/main.dart').readAsStringSync();
  expect(s,contains('_m684InvalidatePeriodRead();\n  entries.clear()'));
  expect(s,contains("traceHomeStep('after_batch_json_decode');\n  _m684InvalidatePeriodRead();"));
  expect(s,contains('_m684InvalidatePeriodRead();\n       entries.insert(0,MoneyEntry('));
  expect(s,contains('_m684InvalidatePeriodRead();\n       setState(()=>entries.insert(0,MoneyEntry('));
  expect(s,contains('_m684InvalidatePeriodRead();\n     setState(()=>entries[index]=initial)'));
  expect(s,contains('_m684InvalidatePeriodRead();\n  setState(()=>entries.removeWhere('));
  expect(s,contains('_m684InvalidatePeriodRead();\n    setState(()=>entries.insert(0,e)'));
  expect(s,contains('_m684InvalidatePeriodRead();entries.clear();smsHashes.clear()'));
  expect(s,contains('_m684InvalidatePeriodRead();\n    entries.clear();'));
  expect(s,contains('_m684InvalidatePeriodRead();\n   entries..clear()..addAll(loaded);'));
 });
}
