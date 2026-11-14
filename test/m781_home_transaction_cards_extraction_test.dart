import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main() {
 test('M781 original Home transaction cards and actions retain all finance guards',(){
  final main=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_transaction_cards.part.dart').readAsStringSync();
  expect(main,contains("part 'waffra_home_transaction_cards.part.dart';"));
  expect(part,startsWith("part of 'main.dart';"));
  expect(part,contains('extension _WaffraHomeTransactionCards on _HomeScreenState'));
  expect(main,isNot(contains(' Future<void> transactionDetails(')));
  for(final marker in <String>[
   ' Widget stat(String label',
   ' Future<void> transactionActions(',
   ' Widget _transactionActionTile(',
   ' Future<void> transactionDetails(',
   ' Widget tile(',
   ' String get greeting=>',
   'readProtectedOriginalSms(entry.id)',
   '_m665ExplainLinkedGoalEdit(paid:true)',
   'WaffraReceiptCornerAction(',
  ]) {
   expect(part,contains(marker),reason:marker);
  }
  expect(part,isNot(contains('_financeAuthority.saveCaptured(')));
 });
 test('M781 source contracts contain actual exact original transaction action UI',(){
  final reconstructed=readWaffraMainSourceForContracts();
  final start=reconstructed.indexOf(' Widget stat(String label');
  final end=reconstructed.indexOf(' Future<void> confirmDeleteAllEntries() async {',start);
  final part=File('lib/waffra_home_transaction_cards.part.dart').readAsStringSync();
  final original=part.substring(part.indexOf(' Widget stat(String label'),
   part.lastIndexOf('\n}')+1);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  expect(reconstructed.substring(start,end),original);
 });
}
