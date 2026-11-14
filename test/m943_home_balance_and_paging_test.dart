import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart' show MoneyEntry,WaffraFinancePeriodIndex;

void main(){
 MoneyEntry row(int n)=>MoneyEntry(
  id:'m943-$n',title:'Record $n',category:'اختبار',
  amount:n.toDouble(),income:n.isEven,
  date:DateTime(2026,11,1+n~/100,10),
  sourceType:'manual');
 test('M943: 2000-item Home read stays bounded and stable across pages',(){
  final index=WaffraFinancePeriodIndex(List.generate(2000,row));
  final total=index.countNewestFirst(where:(e)=>e.income);
  expect(total,1000);
  final first=index.pageNewestFirst(
   offset:0,limit:25,where:(e)=>e.income);
  final next=index.pageNewestFirst(
   offset:25,limit:25,where:(e)=>e.income);
  expect(first.length,25);
  expect(next.length,25);
  expect(first.map((e)=>e.id).toSet()
    .intersection(next.map((e)=>e.id).toSet()),isEmpty);
  expect(index.countNewestFirst(verifiedEntryIds:{'m943-2','m943-3'}),
   2);
  expect(index.pageNewestFirst(
   verifiedEntryIds:{'m943-2','m943-3'},
   offset:0,limit:25,where:(e)=>e.income)
    .single.id,'m943-2');
  expect(index.pageNewestFirst(offset:10,limit:0),isEmpty);
  expect(()=>index.pageNewestFirst(offset:-1,limit:1),throwsRangeError);
 });

 test('M943: unverified Home balance is never ledger-net or a fake month %',(){
  final header=File('lib/waffra_home_balance_header.part.dart').readAsStringSync();
  final flows=File('lib/waffra_home_verified_account_flows.part.dart').readAsStringSync();
  final dashboard=File('lib/waffra_home_dashboard_analytics.part.dart').readAsStringSync();
  expect(header,contains("Key('m943-unverified-home-balance')"));
  expect(header,contains('child:balanceVerified?'));
  expect(flows,contains('if(!_m468VerifiedAccountsLoaded)return 0;'));
  expect(flows,isNot(contains('??waffraAvailableCash(entries,goals)')));
  expect(dashboard,contains('balanceVerified:_m468VerifiedAccountsLoaded'));
  expect(dashboard,contains('monthlyChangePercent:null'));
  expect(dashboard,isNot(contains('final monthChange=')));
  expect(dashboard,contains('_m684Periods.countNewestFirst('));
  expect(dashboard,contains('_m684Periods.pageNewestFirst('));
 });
}
