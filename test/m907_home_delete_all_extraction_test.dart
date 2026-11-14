import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';
void main(){
 test('Original registered part retains precise financial safety assertions',(){
  final main=File('lib/main.dart').readAsStringSync(),part=File('lib/waffra_home_delete_all_transactions.part.dart').readAsStringSync();
  expect(main.split("part 'waffra_home_delete_all_transactions.part.dart';").length,2);
  expect(part,startsWith("part of 'main.dart';"));
  expect(main,isNot(contains(' Future<void> confirmDeleteAllEntries() async {')));
  for(final source in ["if(confirmed!=true||!mounted)return;","'waffra_sms_hashes_v1':<String>[]","route:WaffraFinanceRoute.deleteAllTransactions","await _financialWriteQueue.submit(clear,(captured)async{","userConfirmed:true","setState((){_m684InvalidatePeriodRead();entries.clear();smsHashes.clear();});","unawaited(_refreshWidget());"]){expect(part,contains(source),reason:source);}
 });
 test('Original registered source reassembles byte-identically for old QA',(){
  final full=readWaffraMainSourceForContracts(),part=File('lib/waffra_home_delete_all_transactions.part.dart').readAsStringSync();
  final a=full.indexOf(' Future<void> confirmDeleteAllEntries() async {'),b=full.indexOf(' // M715: budget editor, historical linking and category administration moved to registered Home part.',a);
  expect(a,greaterThan(0));expect(b,greaterThan(a));
  expect(full.substring(a,b),part.substring(part.indexOf(' Future<void> confirmDeleteAllEntries() async {'),part.lastIndexOf('\\n}')+1));
 });
}
