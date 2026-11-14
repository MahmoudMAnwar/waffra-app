import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';
void main(){
 test('Original registered part retains precise financial safety assertions',(){
  final main=File('lib/main.dart').readAsStringSync(),part=File('lib/waffra_home_category_confirmations.part.dart').readAsStringSync();
  expect(main.split("part 'waffra_home_category_confirmations.part.dart';").length,2);
  expect(part,startsWith("part of 'main.dart';"));
  expect(main,isNot(contains(' double sum(Iterable<MoneyEntry> list,bool income)=>')));
  for(final source in ["WaffraRecurringPolicy.toHalalas(e.amount)","waffraCategoryAvailableForNewEntry(categories,c)","c.isSubcategory&&","Future<bool?> confirmDeletion(String title,String body)=>","waffraIsEnglish?'Confirm delete':'تأكيد الحذف'"]){expect(part,contains(source),reason:source);}
 });
 test('Original registered source reassembles byte-identically for old QA',(){
  final full=readWaffraMainSourceForContracts(),part=File('lib/waffra_home_category_confirmations.part.dart').readAsStringSync();
  final a=full.indexOf(' double sum(Iterable<MoneyEntry> list,bool income)=>'),b=full.indexOf(' // M812: verified SMS money-account and optional budget pickers moved to real registered Home part.',a);
  expect(a,greaterThan(0));expect(b,greaterThan(a));
  expect(full.substring(a,b),part.substring(part.indexOf(' double sum(Iterable<MoneyEntry> list,bool income)=>'),part.lastIndexOf('\\n}')+1));
 });
}
