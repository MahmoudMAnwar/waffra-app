import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main(){
 test('M719 the real transaction editor is registered only in its Home part',(){
  final home=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_entry_sheet.part.dart').readAsStringSync();
  expect(home,contains("part 'waffra_home_entry_sheet.part.dart';"));
  expect(part,startsWith("part of 'main.dart';"));
  expect(part,contains('extension _WaffraHomeEntrySheetModule on _HomeScreenState'));
  expect(home,isNot(contains(' Future<void> entrySheet(')));
  expect(part.split(' Future<void> entrySheet(').length,2);
  expect(part,contains('reviewedOriginalSms'));
  expect(part,contains('reviewedSender'));
 });
 test('M719 original editor remains in source finance contract order',(){
  final s=readWaffraMainSourceForContracts();
  final i=s.indexOf(' Future<void> entrySheet(');
  final j=s.indexOf(' Future<String?> chooseTransactionCategory(',i);
  expect(i,greaterThan(0));
  expect(j,greaterThan(i));
  expect(s.substring(i,j),contains('reviewedOriginalSms'));
  expect(s.substring(i,j),contains('reviewedSender'));
 });
}
