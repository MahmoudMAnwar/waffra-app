import 'dart:convert';
import 'dart:io';
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
  final src=File('lib/main.dart').readAsStringSync();
  final start=src.indexOf(' Future<void> persist({');
  final end=src.indexOf(' Future<bool> _persistModuleOrReload(',start);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  final route=src.substring(start,end);
  expect(route,contains('final frozenEntryRows=entries.map((e)=>e.toJson()).toList(growable:false);'));
  expect(route,contains("snapshot['entries']=await WaffraLargeJsonDecode.encodeRecords(frozenEntryRows);"));
  expect(route.indexOf('final frozenEntryRows='),lessThan(route.indexOf('return _saveProgress.track<void>(')));
  expect(route.indexOf("snapshot['entries']=await"),lessThan(route.indexOf('WaffraHomeTransactionCapture.narrowVerifiedModuleEdit(')));
  expect(route,contains('await _financeAuthority.saveCaptured('));
 });
 test('M468 first install and pull use the same verified parsing contract',(){
  final src=File('lib/main.dart').readAsStringSync();
  expect(src,contains('await WaffraLargeJsonDecode.parse(raw)'));
  expect(src,contains('await readList<MoneyEntry>(ledger,MoneyEntry.fromJson)'));
  expect(src,contains('await readList<BudgetCategory>(catalog,BudgetCategory.fromJson)'));
  expect(src,contains('financeView.requireIntegrity();'));
  expect(src,contains('view.requireIntegrity();'));
 });
}
