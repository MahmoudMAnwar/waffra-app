import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main() {
 test('M780 verified deletion and undo remain in the registered original Home module',(){
  final home=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_transaction_ledger_actions.part.dart')
   .readAsStringSync();
  expect(home,contains("part 'waffra_home_transaction_ledger_actions.part.dart';"));
  expect(part,startsWith("part of 'main.dart';"));
  expect(part,contains('extension _WaffraHomeVerifiedLedgerActions on _HomeScreenState'));
  expect(home,isNot(contains(' void _publishVerifiedTransactionLedger(')));
  for(final marker in <String>[
   ' void _publishVerifiedTransactionLedger(',
   ' Future<void> _deleteVerifiedEntry(',
   ' Future<void> _undoVerifiedDeletedEntry(',
   ' Future<void> _showVerifiedDeletedTransactions(',
   ' Future<void> deleteEntry(',
   'WaffraFinanceRoute.transactionDeleteAndUndo',
   '_lastFinanceAuthorityRead',
   '_persistModuleOrReload(',
  ]) {
   expect(part,contains(marker),reason:marker);
  }
  expect(part,isNot(contains('SharedPreferences.getInstance()')));
 });
 test('M780 original finance deletion source is reconstructed without dropping a method',(){
  final actual=readWaffraMainSourceForContracts();
  final start=actual.indexOf(' void _publishVerifiedTransactionLedger(');
  final end=actual.indexOf(' Widget stat(String label',start);
  final part=File('lib/waffra_home_transaction_ledger_actions.part.dart').readAsStringSync();
  final original=part.substring(part.indexOf(' void _publishVerifiedTransactionLedger('),
   part.lastIndexOf('\n}')+1);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  expect(actual.substring(start,end),original);
 });
}
