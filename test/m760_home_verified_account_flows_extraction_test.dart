import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main(){
 test('M760 original verified Home account and two-sided transfer flows are registered exactly',(){
  final main=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_verified_account_flows.part.dart').readAsStringSync();
  expect(main,contains("part 'waffra_home_verified_account_flows.part.dart';"));
  expect(part,startsWith("part of 'main.dart';"));
  expect(part,contains('extension _WaffraHomeVerifiedAccountFlows on _HomeScreenState'));
  expect(main,isNot(contains(' Future<void> _m467RefreshHomeAccounts()async{')));
  for(final witness in <String>[
    ' Future<void> _m467RefreshHomeAccounts()async{',
    ' Future<void> _m468ReadVerifiedAccountsOnce()async{',
    ' List<MoneyEntry> _m684ScopedMonthEntries(',
    ' double _m467ShownBalance(){',
    ' Future<void> _m467PickHomeAccount()async{',
    ' Future<void> openVerifiedAccounts()async{',
    ' Future<void> openVerifiedTransfer()async{',
    '_m627ClosingSession',
    'onConfirmTransfer:(draft)async{',
    'await api.transfer(id:draft.requestId,',
    'note:draft.memo,userConfirmed:true)',
  ]) {
   expect(part,contains(witness),reason:witness);
  }
  expect(part,isNot(contains('saveCaptured(')));
  expect(part,isNot(contains('commitConfirmedSms(')));
  expect(main,contains(" String _m467SelectedAccount='all';"));
 });
 test('M760 old financial UI regression source reconstructs the original account handlers',(){
  final full=readWaffraMainSourceForContracts();
  final begin=full.indexOf(' Future<void> _m467RefreshHomeAccounts()async{');
  final end=full.indexOf(' WaffraFinanceAuthorityRead? _lastFinanceAuthorityRead;',begin);
  final part=File('lib/waffra_home_verified_account_flows.part.dart').readAsStringSync();
  final original=part.substring(part.indexOf(' Future<void> _m467RefreshHomeAccounts()async{'),
   part.lastIndexOf('\n}')+1);
  expect(begin,greaterThan(0));
  expect(end,greaterThan(begin));
  expect(full.substring(begin,end),original);
 });
}
