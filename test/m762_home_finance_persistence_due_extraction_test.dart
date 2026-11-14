import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main(){
 test('M762 registered real finance persistence and due action retain authenticated writer',(){
  final main=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_finance_persistence_due.part.dart').readAsStringSync();
  expect(main,contains("part 'waffra_home_finance_persistence_due.part.dart';"));
  expect(part,startsWith("part of 'main.dart';"));
  expect(part,contains('extension _WaffraHomeFinancePersistenceDue on _HomeScreenState'));
  expect(main,isNot(contains(' Future<void> persist({')));
  for(final marker in <String>[
   ' Future<void> persist({',
   ' Future<bool> _persistModuleOrReload(',
   ' Future<void> _persistSmsHashes(',
   ' Future<void> syncRecurringReminders()async {',
   ' Future<void> toggleRecurringReminders(',
   ' Future<void> applyRecurring()async {',
   '_financeAuthority.saveCaptured(',
   'WaffraFinanceRoute.recurringPostingAndPostponement',
   '_dueDialogShowing=false',
  ]) {
   expect(part,contains(marker),reason:marker);
  }
  expect(main,contains(' Future<void> _refreshWidget()async{'));
 });
 test('M762 original verified finance code and due source reconstruct exactly',(){
  final all=readWaffraMainSourceForContracts();
  final begin=all.indexOf(' Future<void> persist({');
  final end=all.indexOf(' double sum(Iterable<MoneyEntry>',begin);
  final part=File('lib/waffra_home_finance_persistence_due.part.dart')
   .readAsStringSync();
  final same=part.substring(part.indexOf(' Future<void> persist({'),
   part.lastIndexOf('\n}')+1);
  expect(begin,greaterThan(0));
  expect(end,greaterThan(begin));
  expect(all.substring(begin,end),same);
 });
}
