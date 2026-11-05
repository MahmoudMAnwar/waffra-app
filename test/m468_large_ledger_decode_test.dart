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
 test('M468 first install and pull use the same verified parsing contract',(){
  final src=File('lib/main.dart').readAsStringSync();
  expect(src,contains('await WaffraLargeJsonDecode.parse(raw)'));
  expect(src,contains('await readList<MoneyEntry>(ledger,MoneyEntry.fromJson)'));
  expect(src,contains('await readList<BudgetCategory>(catalog,BudgetCategory.fromJson)'));
  expect(src,contains('financeView.requireIntegrity();'));
  expect(src,contains('view.requireIntegrity();'));
 });
}
