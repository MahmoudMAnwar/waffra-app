import 'dart:convert';
import 'dart:io';
import 'support/waffra_main_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_large_json_decode.dart';

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 test('M468 large verified ledger JSON decodes with the same record order',()async{
  final rows=List.generate(5000,(i)=>{'id':'large-$i',
   'title':'A confirmed financial entry $i','amount':i+0.25,
   'income':i.isEven,'accountId':null});
  final source=jsonEncode(rows);
  expect(source.length,greaterThan(WaffraLargeJsonDecode.isolateThreshold));
  final decoded=await WaffraLargeJsonDecode.parse(source);
  expect(decoded,rows);
 });
 test('M468 small JSON and invalid snapshots are not silently replaced',()async{
  expect(await WaffraLargeJsonDecode.parse('{"a":1}'),{'a':1});
  await expectLater(WaffraLargeJsonDecode.parse('[invalid'),throwsFormatException);
 });
 test('M468 frozen save snapshot encodes exactly without blocking UI at scale',()async{
  final records=List.generate(500,(i)=>{'id':'entry-$i',
   'amount':i+0.15,'income':i.isEven,'category':'manual'});
  final expected=jsonEncode(records);
  expect(await WaffraLargeJsonDecode.encodeRecords(records),expected);
  expect(jsonDecode(await WaffraLargeJsonDecode.encodeRecords(records)),records);
 });
 test('M468 save freezes the ledger before deferring encoding and guarding',(){
  final src=readWaffraMainSourceForContracts();
  final start=src.indexOf(' Future<void> persist({');
  final end=src.indexOf(' Future<bool> _persistModuleOrReload(',start);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  final route=src.substring(start,end);
  // M530 strengthens the original M468 freeze with immutable final-field
  // snapshot references. Worker encoding still happens only AFTER the frame.
  expect(route,contains('final frozenEntries=List<MoneyEntry>.unmodifiable(entries);'));
  expect(route,contains('await compute(MoneyEntry.encodeFrozenSnapshot,frozenEntries)'));
  expect(route,contains('await WaffraLargeJsonDecode.encodeRecords('));
  expect(route.indexOf('final frozenEntries='),lessThan(route.indexOf('final saving=_saveProgress.track<void>(')));
  expect(route,contains('final previousWrite=_m468PersistSequence;'));
  expect(route,contains('await previousWrite;'));
  expect(route,contains('_m468PersistSequence=saving.then<void>('));
  expect(route.indexOf('await previousWrite;'),lessThan(route.indexOf("snapshot['entries']=frozenEntries.length>=")));
  expect(route.indexOf("snapshot['entries']=frozenEntries.length>="),lessThan(route.indexOf('WaffraHomeTransactionCapture.narrowVerifiedModuleEdit(')));
  expect(route,contains('await _financeAuthority.saveCaptured('));
 });
 test('M468 first install and pull use the same verified parsing contract',(){
  final src=readWaffraMainSourceForContracts();
  expect(src,contains('await WaffraLargeJsonDecode.parse(raw)'));
  // M603: verified ledger projection yields after bounded mapping,
  // retaining all rows, their order and source integrity checks.
  // M607: normalized authority ledger is non-null; never silently replace
  // invalid verified ciphertext with an empty financial history.
  expect(src,contains('final refreshSource=WaffraVerifiedPullRefreshSource.fromAuthority(current);'));
  expect(src,contains('final nextEntries=await _m593BuildVerifiedEntries('));
  expect(src,contains('(await WaffraLargeJsonDecode.parse(ledger)) as List)'));
  expect(src,isNot(contains('final nextEntries=ledger==null?<MoneyEntry>[]:')));
  expect(src,contains('await _m593BuildVerifiedEntries('));
  expect(src,contains('const batchSize=96;'));
  expect(src,contains('MoneyEntry.fromJson(Map<String,dynamic>.from(row))'));
  expect(src,contains('await Future<void>.delayed(Duration.zero)'));
  expect(src,contains('await readList<BudgetCategory>(catalog,BudgetCategory.fromJson)'));
  expect(src,contains('financeView.requireIntegrity();'));
  expect(src,contains('view.requireIntegrity();'));
 });
}
