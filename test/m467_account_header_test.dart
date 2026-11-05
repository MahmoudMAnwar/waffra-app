import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_home_accounts_sheet.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
void main(){
 testWidgets('M467 approved all-account picker exposes money and unassigned',
   (tester)async{
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:
   WaffraHomeAccountsSheet(english:false,selected:'all',
    accounts:const [
     WaffraAccountBalance('one','مصرف الراجحي','bank',520000,false),
     WaffraAccountBalance('two','نقدي','cash',7000,false),
    ]))));
  expect(find.byKey(const Key('m467-account-choice-all')),findsOneWidget);
  expect(find.byKey(const Key('m467-account-choice-one')),findsOneWidget);
  expect(find.byKey(const Key('m467-account-choice-two')),findsOneWidget);
  expect(find.byKey(const Key('m467-account-choice-none')),findsOneWidget);
  expect(find.byKey(const Key('m467-manage-accounts')),findsOneWidget);
 });
 test('M467 Home header scope is verified and never passed into finance commits',(){
  final src=File('lib/main.dart').readAsStringSync();
  expect(src,contains('WaffraHomeAccountChip('));
  expect(src,contains('_m467ScopedEntries().toList()'));
  expect(src,contains('api.readAccountContext('));
  expect(src,contains('_m467Accounts.fold<int>(0,(total,a)=>total+a.balanceMinor)/100'));
  expect(src,contains('if(transferCommitted&&mounted){'));
  expect(src,contains('unawaited(_m467RefreshHomeAccounts());'));
  expect(src,contains('if(account.id==_m467SelectedAccount)return account.name;'));
  expect(src,isNot(contains('selectedAccountId:_m467SelectedAccount')));
 });
}
