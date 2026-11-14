import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main() {
 test('M795 original category selection and encrypted receipt actions are registered',(){
  final home=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_category_receipt_dialogs.part.dart').readAsStringSync();
  expect(home,contains("part 'waffra_home_category_receipt_dialogs.part.dart';"));
  expect(part,startsWith("part of 'main.dart';"));
  expect(part,contains('extension _WaffraHomeCategoryReceiptDialogs on _HomeScreenState'));
  expect(home,isNot(contains(' Future<String?> chooseTransactionCategory(')));
  for(final anchor in <String>[
   ' Future<String?> chooseTransactionCategory(',
   ' Future<String?> _promptReceiptLabel(',
   ' Future<String> saveReceipt(',
   ' Future<void> showReceipt(',
   'WaffraValidators.uniqueCategory(',
   'waffraReceiptPaths(',
  ]) {
   expect(part,contains(anchor),reason:anchor);
  }
  expect(part,contains('encrypted'));
  expect(readWaffraMainSourceForContracts(),contains(' Future<void> _requestPercentageAlertPermission()async{'));
 });
 test('M795 existing receipt/category assertions inspect genuine registered Dart source',(){
  final whole=readWaffraMainSourceForContracts();
  final start=whole.indexOf(' Future<String?> chooseTransactionCategory(');
  final end=whole.indexOf(' Future<void> _requestPercentageAlertPermission()async{',start);
  final part=File('lib/waffra_home_category_receipt_dialogs.part.dart').readAsStringSync();
  final original=part.substring(part.indexOf(' Future<String?> chooseTransactionCategory('),
   part.lastIndexOf('\n}')+1);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  expect(whole.substring(start,end),original);
 });
}
