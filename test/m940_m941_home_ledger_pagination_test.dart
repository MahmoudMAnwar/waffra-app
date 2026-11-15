import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart' show MoneyEntry,
 WaffraFinancePeriodIndex,WaffraHomeLedgerReadCache,
 WaffraHomeTransactionFilter;

MoneyEntry synthetic(int n,{
 bool income=false,String sourceType='manual',String category='تجربة',
})=>MoneyEntry(
 id:'entry-$n',title:'Transaction $n',category:category,
 amount:(n%400+1).toDouble(),income:income,
 date:DateTime(2026,1,1).add(Duration(minutes:n)),
 sourceType:sourceType);

void main(){
 test('M940 2500 records: chronological pages have no skipped or repeated IDs',(){
  final rows=List<MoneyEntry>.generate(2500,(i)=>synthetic(i));
  final read=WaffraFinancePeriodIndex(rows.reversed);
  final all=read.newestFirst();
  expect(all.length,2500);
  expect(all.first.id,'entry-2499');
  expect(all.last.id,'entry-0');
  final pageIds=<String>[];
  for(var offset=0;offset<2500;offset+=73){
   final page=read.pageNewestFirst(offset:offset,limit:73);
   expect(page.length,offset+73<=2500?73:2500-offset);
   pageIds.addAll(page.map((e)=>e.id));
  }
  expect(pageIds,all.map((e)=>e.id).toList());
  expect(pageIds.toSet().length,2500);
  expect(read.pageNewestFirst(offset:2500,limit:73),isEmpty);
  expect(read.pageNewestFirst(offset:0,limit:0),isEmpty);
  expect(()=>read.pageNewestFirst(offset:-1,limit:4),throwsRangeError);
  expect(()=>read.pageNewestFirst(offset:0,limit:-1),throwsRangeError);
  expect(()=>all.clear(),throwsUnsupportedError);
 });

 test('M940 exact verified account IDs and filters exclude unassigned money',(){
  final rows=List<MoneyEntry>.generate(2400,(i)=>synthetic(i,
   income:i.isEven,sourceType:i%3==0?'goal_due':'manual'));
  final read=WaffraFinancePeriodIndex(rows);
  final ids={for(var i=0;i<2400;i++)if(i%5==0)'entry-$i'};
  final scoped=read.newestFirst(verifiedEntryIds:ids,
   where:(e)=>!e.income);
  expect(scoped.length,240);
  expect(scoped.every((e)=>ids.contains(e.id)&&!e.income),isTrue);
  for(var offset=0;offset<scoped.length;offset+=31){
   expect(read.pageNewestFirst(verifiedEntryIds:ids,
    where:(e)=>!e.income,offset:offset,limit:31),
    scoped.skip(offset).take(31).toList());
  }
  expect(read.newestFirst(verifiedEntryIds:<String>{}),isEmpty);
  expect(read.pageNewestFirst(verifiedEntryIds:<String>{},offset:0,limit:20),isEmpty);
  expect(read.newestFirst(verifiedEntryIds:{'missing'}),isEmpty);
  expect(read.newestFirst().length,2400);
 });

 test('M940 matching dates retain original ledger position',(){
  final tied=[3,1,2].map((n)=>MoneyEntry(
   id:'entry-$n',title:'Transaction $n',category:'تجربة',
   amount:n.toDouble(),income:false,date:DateTime(2026,11,14),
   sourceType:'manual')).toList();
  final read=WaffraFinancePeriodIndex(tied);
  expect(read.newestFirst().map((e)=>e.id),['entry-3','entry-1','entry-2']);
  expect(read.pageNewestFirst(offset:1,limit:1).single.id,'entry-1');
 });

 test('M941 read snapshot changes ONLY after explicit ledger invalidation',(){
  final rows=[synthetic(1)];
  final cache=WaffraHomeLedgerReadCache();
  final first=cache.index(rows);
  expect(identical(first,cache.index(rows)),isTrue);
  rows.add(synthetic(2));
  expect(first.newestFirst().length,1);
  cache.invalidate();
  final refreshed=cache.index(rows);
  expect(identical(first,refreshed),isFalse);
  expect(refreshed.newestFirst().map((e)=>e.id),['entry-2','entry-1']);
  expect(refreshed.newestFirst().fold<double>(0,(a,e)=>a+e.amount),5);
 });

 test('M941 extracted filters preserve dates, category, amount and paid dues',(){
  final expense=synthetic(10,category:'مشتريات');
  final due=synthetic(20,sourceType:'goal_due',category:'ادخار');
  final date=DateTime(2026,1,1);
  final filter=WaffraHomeTransactionFilter(
   search:'Transaction',typeFilter:'الاستحقاقات',categoryFilter:'ادخار',
   dateRange:DateTimeRange(start:date,end:date.add(const Duration(days:2))),
   minAmount:20,maxAmount:30);
  expect(filter.acceptsType(expense),isFalse);
  expect(filter.acceptsType(due),isTrue);
  expect(filter.accepts(expense),isFalse);
  expect(filter.accepts(due),isTrue);
  expect(WaffraHomeTransactionFilter(search:'no-such-title',
   typeFilter:'الكل',categoryFilter:'الكل').accepts(due),isFalse);
  expect(WaffraHomeTransactionFilter(search:'',
   typeFilter:'الكل',categoryFilter:'الكل').accepts(expense),isTrue);
 });

 test('M940/M941 production Home and summary share source-verified read query',(){
  final main=File('lib/main.dart').readAsStringSync();
  final dash=File('lib/waffra_home_dashboard_analytics.part.dart').readAsStringSync();
  final summary=File('lib/waffra_home_transaction_summary.part.dart').readAsStringSync();
  final query=File('lib/waffra_home_ledger_query.part.dart').readAsStringSync();
  expect(main,contains("part 'waffra_home_ledger_query.part.dart';"));
  final helpers=File('lib/waffra_home_state_core_helpers.part.dart').readAsStringSync();
  expect(main,contains("part 'waffra_home_state_core_helpers.part.dart';"));
  expect(helpers,contains('void _m684InvalidatePeriodRead(){'));
  expect(helpers,contains('_m940LedgerReads.invalidate();'));
  expect(helpers,contains('_m945UnifiedHistoryScope=null;'));
  expect(helpers,contains('_m945UnifiedHistoryCount=null;'));
  expect(dash,contains('where:transactionFilter.accepts'));
  expect(dash,contains('_m684ScopedEntryIds??const <String>{}'));
  expect(summary,contains('where:(e)=>e.income==income'));
  expect(summary,contains('_m684ScopedEntryIds??const <String>{}'));
  expect(query,isNot(contains('INSERT INTO')));
  expect(query,isNot(contains('UPDATE ')));
  expect(query,isNot(contains('DELETE FROM')));
 });
}
