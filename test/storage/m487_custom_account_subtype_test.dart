import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_account_details_schema.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_custom_account_subtype_schema.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 late Directory directory;
 late WaffraEncryptedStore store;
 late WaffraAccountsRepository accounts;
 const now='2026-11-06T14:00:00';
 setUp(()async{
  directory=await Directory.systemTemp.createTemp('waffra-m487-');
  store=WaffraEncryptedStore.openAt(
   File('${directory.path}/vault.sqlite'),
   key:'m487-throwaway-verified-finance-test');
  await WaffraFreshEncryptedVaultBootstrap(
   store:store,experimentalEnabled:true).initialize(
    decision:WaffraFirstRunDecision.freshCandidate);
  await WaffraAccountsSchema.install(store);
  await WaffraAccountDetailsSchema.install(store);
  accounts=WaffraAccountsRepository(db:store,experimentalEnabled:true);
  await accounts.createAccount(id:'bank-1',name:'Inma checking',
   kind:'bank',openingMinor:150000,createdIso:now,userConfirmed:true);
  await accounts.createAccount(id:'cash-1',name:'Cash',
   kind:'cash',openingMinor:25000,createdIso:now,userConfirmed:true);
  await WaffraAccountDetailsSchema.assign(store,
   accountId:'bank-1',kind:'bank',providerId:'inma',
   subtype:'other',confirmedIso:now);
 });
 tearDown(()async{
  await store.close();
  if(await directory.exists())await directory.delete(recursive:true);
 });

 test('M487 optional metadata keeps legacy balances and categories',()async{
  final original=await accounts.balances();
  expect(original.singleWhere((x)=>x.id=='bank-1').balanceMinor,150000);
  expect(original.singleWhere((x)=>x.id=='bank-1').customSubtypeLabel,isNull);
  await WaffraCustomAccountSubtypeSchema.install(store);
  await WaffraCustomAccountSubtypeSchema.assign(store,
   accountId:'bank-1',kind:'bank',label:'راتب جانبي',
   confirmedIso:now);
  final updated=await accounts.balances();
  final bank=updated.singleWhere((x)=>x.id=='bank-1');
  expect(bank.kind,'bank');
  expect(bank.providerId,'inma');
  expect(bank.subtype,'other');
  expect(bank.customSubtypeLabel,'راتب جانبي');
  expect(bank.balanceMinor,150000);
  expect(updated.singleWhere((x)=>x.id=='cash-1').balanceMinor,25000);
  await WaffraCustomAccountSubtypeSchema.install(store);
  expect((await accounts.balances()).singleWhere(
   (x)=>x.id=='bank-1').customSubtypeLabel,'راتب جانبي');
 });

 test('M487 rejects unsafe labels and wrong account kinds',()async{
  await WaffraCustomAccountSubtypeSchema.install(store);
  for(final invalid in ['', 'x', 'bad\\nname', 'x'*41]){
   await expectLater(WaffraCustomAccountSubtypeSchema.assign(store,
    accountId:'bank-1',kind:'bank',label:invalid,confirmedIso:now),
    throwsA(isA<ArgumentError>()));
  }
  await expectLater(WaffraCustomAccountSubtypeSchema.assign(store,
   accountId:'cash-1',kind:'bank',label:'Premium wallet',
   confirmedIso:now),throwsA(isA<StateError>()));
  expect((await accounts.balances()).singleWhere(
   (x)=>x.id=='bank-1').customSubtypeLabel,isNull);
 });

 test('M487 storage and UI protect the canonical subtype writer',(){
  final adapter=File('lib/storage/waffra_verified_accounts_api.dart')
   .readAsStringSync();
  final dialog=File('lib/waffra_new_account_dialog.dart')
   .readAsStringSync();
  final manager=File('lib/waffra_accounts_manager_page.dart')
   .readAsStringSync();
  expect(adapter,contains('WaffraCustomAccountSubtypeSchema.assign('));
  expect(adapter,contains('customSubtypeLabel:'));
  expect(dialog,contains('m487-custom-account-subtype-save'));
  expect(manager,contains('customSubtypeOptions:customSubtypes'));
  expect(adapter,contains('WaffraAccountDetailsSchema.assign('));
 });
}
