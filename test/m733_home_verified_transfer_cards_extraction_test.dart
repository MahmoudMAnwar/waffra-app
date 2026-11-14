import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main(){
 test('M733 Home uses only registered unchanged verified transfer cards',(){
  final main=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_verified_transfer_cards.part.dart')
   .readAsStringSync();
  expect(main,contains("part 'waffra_home_verified_transfer_cards.part.dart';"));
  expect(part,startsWith("part of 'main.dart';"));
  expect(part,contains('extension _WaffraHomeVerifiedTransferCards on _HomeScreenState'));
  expect(main,isNot(contains(' String _m647VerifiedAccountLabel(')));
  expect(part,contains(' String _m647VerifiedAccountLabel('));
  expect(part,contains(' Widget _m647TransferCard('));
  expect(part,contains(' Widget _m649SavingsCard('));
  expect(part,contains(' Future<void> _m647ShowInternalTransfers('));
  expect(part,contains('_m467SelectedAccount==t.fromAccountId'));
  expect(part,contains('_m467SelectedAccount==t.toAccountId'));
  expect(part,contains('movement.amountMinor/100'));
  expect(part,contains("movement.kind=='fund'"));
  expect(part,isNot(contains('_financeAuthority.saveCaptured(')));
  expect(part,isNot(contains('_financeAuthority.commitConfirmedSms(')));
 });
 test('M733 old finance/UI source contracts inspect actual registered part',(){
  final full=readWaffraMainSourceForContracts();
  final start=full.indexOf(' String _m647VerifiedAccountLabel(');
  final end=full.indexOf(' Widget compactTransaction(',start);
  final file=File('lib/waffra_home_verified_transfer_cards.part.dart')
   .readAsStringSync();
  final source=file.substring(file.indexOf(' String _m647VerifiedAccountLabel('),
   file.lastIndexOf('\n}')+1);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  expect(full.substring(start,end),source);
 });
}
