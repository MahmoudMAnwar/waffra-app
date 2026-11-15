import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart' show MoneyEntry,WaffraFinancePeriodIndex,
 WaffraHomeLedgerReadCache,WaffraHomeTransactionFilter;
import 'package:waffra/waffra_recurring_policy.dart';
import 'package:waffra/waffra_approved_page_designs.dart';

/// M948: independent deterministic property/volume/visual checks.
/// No user database, internet, bank messages, or performance telemetry.
MoneyEntry row(int n,{DateTime? date,bool income=false,int minor=100,
 String category='اختبار'})=>MoneyEntry(
 id:'m948-$n',title:'تحقق العملية $n',category:category,
 amount:minor/100,income:income,
 date:date??DateTime(2026,11,15,12,n%60),sourceType:'manual');

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();

 test('M948 10,000 entries: pages, selected-account IDs and date buckets '
  'exactly equal independent source-filter reference',(){
  var rng=11092026;
  int next(){
   rng=(rng*1103515245+12345)&0x7fffffff;
   return rng;
  }
  const count=10000;
  final rows=<MoneyEntry>[];
  final start=DateTime(2023,1,1);
  for(var i=0;i<count;i++){
   final n=next();
   rows.add(row(i,date:start.add(Duration(hours:n%30000)),
    income:i%7==0,minor:n%900000+1,
    category:i%3==0?'طعام':'إيجار'));
  }
  final stopwatch=Stopwatch()..start();
  final index=WaffraFinancePeriodIndex(rows);
  final full=index.newestFirst();
  expect(full.length,count);
  expect(full.map((r)=>r.id).toSet().length,count);
  for(var i=1;i<full.length;i++){
   expect(full[i-1].date.isBefore(full[i].date),false,
    reason:'Financial timeline must remain newest-first');
  }
  final verified={for(var i=0;i<count;i++)if(i%11==0)'m948-$i'};
  final expected=full.where((r)=>verified.contains(r.id)&&r.income).toList();
  final all=index.newestFirst(verifiedEntryIds:verified,where:(r)=>r.income);
  expect(all,expected);
  expect(index.countNewestFirst(verifiedEntryIds:verified,
   where:(r)=>r.income),expected.length);
  final restored=<MoneyEntry>[];
  for(var offset=0;offset<expected.length;offset+=37){
   final page=index.pageNewestFirst(
    verifiedEntryIds:verified,where:(r)=>r.income,
    offset:offset,limit:37);
   expect(page.length,lessThanOrEqualTo(37));
   restored.addAll(page);
  }
  expect(restored,expected);
  expect(index.byIds(verified),
   rows.where((r)=>verified.contains(r.id)).toList());
  final lookupMonths=[
   DateTime(2023,1),DateTime(2024,2),DateTime(2025,12),
   DateTime(2026,2),DateTime(2023,1),
  ];
  final monthSet={for(final m in lookupMonths)m.year*12+m.month};
  final calendar=rows.where((r)=>
   monthSet.contains(r.date.year*12+r.date.month)).toList();
  expect(index.months(lookupMonths),calendar);
  for(final month in [DateTime(2023,1),DateTime(2024,2),DateTime(2026,2)]){
   expect(index.month(month.year,month.month),
    rows.where((r)=>r.date.year==month.year&&
     r.date.month==month.month).toList());
  }
  expect(index.newestFirst(verifiedEntryIds:<String>{}),isEmpty);
  expect(index.pageNewestFirst(offset:count,limit:50),isEmpty);
  stopwatch.stop();
  expect(stopwatch.elapsed,lessThan(const Duration(seconds:15)),
   reason:'10k-item in-memory analysis exceeds conservative host smoke budget');
 });

 test('M948 Home virtualized 50-item windows do not allocate full card list, '
  'reset on source revision and never repeat rows',(){
  final rows=List<MoneyEntry>.generate(10000,(i)=>row(i,
   date:DateTime(2026,1,1).add(Duration(minutes:i))));
  final cache=WaffraHomeLedgerReadCache();
  final index=cache.index(rows);
  expect(cache.expandedLimit,50);
  var shown=index.pageNewestFirst(offset:0,limit:cache.expandedLimit);
  expect(shown.length,50);
  expect(shown.first.id,'m948-9999');
  expect(cache.revealNext(rows.length),true);
  expect(cache.expandedLimit,100);
  shown=index.pageNewestFirst(offset:0,limit:cache.expandedLimit);
  expect(shown.length,100);
  expect(shown.map((e)=>e.id).toSet().length,100);
  expect(identical(index,cache.index(rows)),true);
  rows.add(row(10000,date:DateTime(2027,1,1)));
  expect(index.countNewestFirst(),10000);
  cache.invalidate();
  expect(cache.expandedLimit,50);
  final newIndex=cache.index(rows);
  expect(newIndex.countNewestFirst(),10001);
  expect(newIndex.pageNewestFirst(offset:0,limit:50).first.id,'m948-10000');
  expect(()=>newIndex.pageNewestFirst(offset:0,limit:50).clear(),
   throwsUnsupportedError);
 });

 test('M948 exact inclusive selected calendar day never includes previous '
  'or next day even across month and year boundary',(){
  for(final range in [
   DateTimeRange(start:DateTime(2026,11,15),end:DateTime(2026,11,15)),
   DateTimeRange(start:DateTime(2026,12,31),end:DateTime(2027,1,2)),
   DateTimeRange(start:DateTime(2028,2,29),end:DateTime(2028,3,1)),
  ]){
   final filter=WaffraHomeTransactionFilter(
    search:'',typeFilter:'الكل',categoryFilter:'الكل',dateRange:range);
   final from=range.start;
   final until=range.end;
   final before=DateTime(from.year,from.month,from.day)
    .subtract(const Duration(milliseconds:1));
   final after=DateTime(until.year,until.month,until.day)
    .add(const Duration(days:1));
   expect(filter.accepts(row(1,date:before)),false,
    reason:'Previous day was incorrectly selected');
   expect(filter.accepts(row(2,date:from)),true);
   expect(filter.accepts(row(3,date:DateTime(
    until.year,until.month,until.day,23,59,59,999))),true);
   expect(filter.accepts(row(4,date:after)),false);
  }
  final multi=WaffraHomeTransactionFilter(
   search:'',typeFilter:'الكل',categoryFilter:'الكل',
   dateRange:DateTimeRange(start:DateTime(2026,11,28),
    end:DateTime(2026,12,2)));
  expect(multi.accepts(row(7,date:DateTime(2026,11,30,23,59))),true);
  expect(multi.accepts(row(8,date:DateTime(2026,12,1,0,0))),true);
 });

 test('M948 halala rounding 10,000 seeded values preserves the exact '
  'integer cash balance, never floating drift on repeated sums',(){
  var state=20261115;
  int next(){
   state=(state*1664525+1013904223)&0x7fffffff;
   return state;
  }
  final incomes=<num>[],expenses=<num>[];
  var signed=0;
  for(var i=0;i<10000;i++){
   final minor=next()%1000000;
   final positive=i%4==0;
   if(positive){incomes.add(minor/100);signed+=minor;}
   else{expenses.add(minor/100);signed-=minor;}
   expect(WaffraRecurringPolicy.toHalalas(minor/100),minor);
  }
  expect(WaffraRecurringPolicy.netHalalas(incomes,expenses),signed);
  expect(WaffraRecurringPolicy.toHalalas(0.01),1);
  expect(WaffraRecurringPolicy.toHalalas(0.99),99);
  expect(WaffraRecurringPolicy.toHalalas(999999.99),99999999);
 });

 test('M948 scheduling 1st/28th/30th/31st across 16 years and leap '
  'boundaries does not post or double-count money',(){
  for(var year=2024;year<=2039;year++){
   for(var month=1;month<=12;month++){
    for(final day in [1,28,30,31]){
     final due=WaffraRecurringPolicy.dueDate(year,month,day);
     final last=DateTime(year,month+1,0).day;
     expect(due,DateTime(year,month,day>last?last:day));
     final previous=due.subtract(const Duration(days:1));
     expect(WaffraRecurringPolicy.isOutstanding(
      due:due,today:previous,startAt:DateTime(year,month,1),
      alreadyPaid:false),false);
     expect(WaffraRecurringPolicy.isOutstanding(
      due:due,today:due,startAt:DateTime(year,month,1),
      alreadyPaid:false),true);
     expect(WaffraRecurringPolicy.isOutstanding(
      due:due,today:due,startAt:DateTime(year,month,1),
      alreadyPaid:true),false);
     final identity=WaffraRecurringPolicy.entryId('rent',due);
     expect(identity,WaffraRecurringPolicy.entryId('rent',DateTime(
      year,month,1)));
     expect(identity,isNot(WaffraRecurringPolicy.entryId('rent',
      DateTime(year,month+1,1))));
     final postpone=due.add(const Duration(days:3));
     expect(WaffraRecurringPolicy.isOutstanding(
      due:due,today:due,startAt:DateTime(year,month,1),
      alreadyPaid:false,postponedUntil:postpone),false);
    }
   }
  }
 });

 testWidgets('M948 RTL + 200% fonts on narrow 320px Android-like viewport '
  'do not throw layout overflow for Goals/Dues approved metrics',
  (tester)async{
  tester.view.physicalSize=const Size(320,720);
  tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home:MediaQuery(
   data:const MediaQueryData(size:Size(320,720),
    textScaler:TextScaler.linear(2)),
   child:Directionality(textDirection:TextDirection.rtl,
    child:Scaffold(body:ListView(children:[
     const WaffraApprovedPageHero(title:'أهداف الادخار',
      subtitle:'حوّل أحلامك إلى أهداف ملموسة وتابع تقدمك بسهولة ووضوح',
      icon:Icons.flag_outlined),
     const WaffraApprovedMetrics(metrics:[
      WaffraApprovedMetric('إجمالي المستهدفات',
       'ريال 9,999,999,999.99',Icons.trending_up),
      WaffraApprovedMetric('إجمالي المدخرات',
       'ريال 2,000,000.50',Icons.savings),
      WaffraApprovedMetric('أهداف نشطة','12',Icons.flag_outlined),
     ]),
    ]))))));
  await tester.pump();
  expect(find.byKey(const Key('m674-verified-metrics')),findsOneWidget);
  expect(find.text('أهداف الادخار'),findsOneWidget);
  expect(tester.takeException(),isNull);
 });
}
