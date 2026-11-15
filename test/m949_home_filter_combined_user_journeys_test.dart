import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart' show MoneyEntry,
 WaffraHomeTransactionFilter,WaffraFinancePeriodIndex;

/// M949: independently assert NEW multi-control user filter combinations.
/// Existing M940/M948 test individual controls; these test their interactions.
MoneyEntry item(int id,{String title='معاملة',
 String category='طعام',bool income=false,
 double amount=100,DateTime? date,String source='manual'})=>MoneyEntry(
 id:'m949-'+id.toString(),title:title,category:category,
 amount:amount,income:income,
 date:date??DateTime(2026,11,15,12),sourceType:source);

WaffraHomeTransactionFilter filter({
 String search='',String type='الكل',String category='الكل',
 DateTimeRange? dates,double? min,double? max})=>
 WaffraHomeTransactionFilter(search:search,typeFilter:type,
  categoryFilter:category,dateRange:dates,minAmount:min,maxAmount:max);

void main(){
 test('M949-F01 all five filters applied together select one legitimate expense',(){
  final rows=[
   item(1,title:'فَاتورة كَهْرباء',category:'فواتير',
    amount:125.75,date:DateTime(2026,11,15,8)),
   item(2,title:'فاتورة كهرباء',category:'فواتير',
    amount:125.75,date:DateTime(2026,11,14,23,59)),
   item(3,title:'فاتورة كهرباء',category:'طعام',
    amount:125.75,date:DateTime(2026,11,15,8)),
   item(4,title:'فاتورة كهرباء',category:'فواتير',
    amount:300,date:DateTime(2026,11,15,8)),
   item(5,title:'فاتورة كهرباء',category:'فواتير',
    amount:125.75,income:true,date:DateTime(2026,11,15,8)),
  ];
  final f=filter(search:'  فاتوره  ',type:'المصروفات',category:'فواتير',
   min:125.75,max:125.75,
   dates:DateTimeRange(start:DateTime(2026,11,15),
    end:DateTime(2026,11,15)));
  expect(rows.where(f.accepts).map((x)=>x.id).toList(),['m949-1']);
 });

 test('M949-F02 single-halalah amount range is inclusive at both edges',(){
  final rows=[item(1,amount:1.00),item(2,amount:1.01),
   item(3,amount:1.02),item(4,amount:0.99)];
  final f=filter(min:1.00,max:1.01);
  expect(rows.where(f.accepts).map((r)=>r.id).toList(),
   ['m949-1','m949-2']);
 });

 test('M949-F03 identical title and category never mixes salary with spending',(){
  final rows=[item(1,title:'كاش',category:'أخرى',income:true),
   item(2,title:'كاش',category:'أخرى'),
   item(3,title:'كاش',category:'راتب',income:true)];
  final f=filter(search:'كاش',type:'الدخل',category:'أخرى');
  expect(rows.where(f.accepts).map((r)=>r.id).toList(),['m949-1']);
 });

 test('M949-F04 dues filter keeps recurring and goal due, not ordinary expense',(){
  final rows=[item(1,title:'إيجار',source:'recurring'),
   item(2,title:'إيجار',source:'goal_due'),
   item(3,title:'إيجار',source:'manual'),
   item(4,title:'إيجار',source:'bank_sms')];
  final f=filter(search:'إيجار',type:'الاستحقاقات');
  expect(rows.where(f.accepts).map((r)=>r.id).toList(),
   ['m949-1','m949-2']);
 });

 test('M949-F05 unexpected persisted type string rejects records, not broadens all',(){
  final rows=[item(1,income:true),item(2)];
  final f=filter(type:'invalid-upgrade-value');
  expect(rows.where(f.accepts),isEmpty);
  expect(rows.where(filter().accepts).length,2);
 });

 test('M949-F06 Arabic diacritics, Alef and Ta Marbuta find title in account slice',(){
  final rows=[item(1,title:'مَدْفوعات الأُسْرَة',category:'طعام'),
   item(2,title:'فواتير المنزل',category:'طعام')];
  final index=WaffraFinancePeriodIndex(rows);
  final f=filter(search:'  مدفوعات الاسره ');
  expect(index.newestFirst(verifiedEntryIds:{'m949-1'},
   where:f.accepts).map((r)=>r.id).toList(),['m949-1']);
  expect(rows.first.title,'مَدْفوعات الأُسْرَة');
 });

 test('M949-F07 equal timestamps still stable when mixed filters narrow account IDs',(){
  final date=DateTime(2026,11,15,12,0);
  final rows=[item(1,date:date,amount:120),
   item(2,date:date,amount:90),
   item(3,date:date,amount:140),
   item(4,date:date,amount:160)];
  final index=WaffraFinancePeriodIndex(rows);
  final f=filter(min:100,max:150,type:'المصروفات');
  expect(index.newestFirst(verifiedEntryIds:{'m949-3','m949-1','m949-4'},
   where:f.accepts).map((e)=>e.id).toList(),['m949-1','m949-3']);
 });

 test('M949-F08 year rollover date and account scope combine without spilling',(){
  final rows=[
   item(1,category:'فواتير',amount:90,date:DateTime(2026,12,31,23,59)),
   item(2,category:'فواتير',amount:90,date:DateTime(2027,1,1,0,0)),
   item(3,category:'فواتير',amount:90,date:DateTime(2027,1,2,0,0)),
   item(4,category:'طعام',amount:90,date:DateTime(2027,1,1,12,0)),
  ];
  final index=WaffraFinancePeriodIndex(rows);
  final f=filter(category:'فواتير',min:80,max:100,
   dates:DateTimeRange(start:DateTime(2026,12,31),
    end:DateTime(2027,1,1)));
  expect(index.newestFirst(verifiedEntryIds:{'m949-2','m949-3','m949-4'},
   where:f.accepts).map((r)=>r.id).toList(),['m949-2']);
  expect(index.newestFirst(where:f.accepts).map((r)=>r.id).toList(),
   ['m949-2','m949-1']);
 });

 test('M949-F09 zero verified IDs cannot leak matching unassigned receipt card',(){
  final rows=[item(1,title:'مصاريف تليفون',category:'فواتير',
   amount:499.0),item(2,title:'مصاريف تليفون',
    category:'فواتير',amount:499.0)];
  final index=WaffraFinancePeriodIndex(rows);
  final f=filter(search:'تليفون',category:'فواتير',min:400);
  expect(index.newestFirst(verifiedEntryIds:<String>{},
   where:f.accepts),isEmpty);
  expect(index.newestFirst(where:f.accepts).length,2);
 });

 test('M949-F10 switching income to expense does not mutate shared verified index',(){
  final rows=[item(1,title:'راتب',income:true,amount:400),
   item(2,title:'مصروف',amount:70),item(3,title:'راتب',income:true,
    amount:500)];
  final index=WaffraFinancePeriodIndex(rows);
  final income=index.newestFirst(where:filter(type:'الدخل').accepts);
  final expense=index.newestFirst(where:filter(type:'المصروفات').accepts);
  expect(income.map((x)=>x.id).toList(),['m949-1','m949-3']);
  expect(expense.map((x)=>x.id).toList(),['m949-2']);
  expect(index.newestFirst().length,3);
  expect(rows.length,3);
 });

 test('M949-F11 account scoped pagination with simultaneous category/amount constraints',(){
  final rows=List<MoneyEntry>.generate(113,(i)=>item(i,
   title:i.isEven?'فواتير':'بقالة',
   category:i%3==0?'فواتير':'طعام',amount:50+i,
   date:DateTime(2026,11,15).add(Duration(minutes:i))));
  final index=WaffraFinancePeriodIndex(rows);
  final scope={for(var i=0;i<113;i++)if(i%4==0)'m949-'+i.toString()};
  final f=filter(search:'فواتير',category:'فواتير',min:80,max:145);
  final expected=rows.where((r)=>scope.contains(r.id)&&f.accepts(r))
   .toList().reversed.toList();
  final actual=<MoneyEntry>[];
  for(var offset=0;offset<expected.length;offset+=5){
   actual.addAll(index.pageNewestFirst(
    verifiedEntryIds:scope,where:f.accepts,offset:offset,limit:5));
  }
  expect(actual,expected);
  expect(actual.map((r)=>r.id).toSet().length,expected.length);
  expect(index.countNewestFirst(verifiedEntryIds:scope,
   where:f.accepts),expected.length);
 });

 test('M949-F12 impossible min/max amount intersection shows empty without loss',(){
  final rows=[item(1,amount:49),item(2,amount:50),
   item(3,amount:51)];
  final index=WaffraFinancePeriodIndex(rows);
  final impossible=filter(min:70,max:20);
  expect(index.newestFirst(where:impossible.accepts),isEmpty);
  expect(index.newestFirst().map((r)=>r.amount).toList(),[49,50,51]);
 });
}
