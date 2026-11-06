import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_account_context_repository.dart';
import 'package:waffra/storage/waffra_account_context_schema.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 late Directory directory;
 late WaffraEncryptedStore store;
 late WaffraAccountContextRepository context;
 late WaffraAccountsRepository accounts;
 const timestamp='2026-11-06T14:00:00';
 setUp(()async{
  directory=await Directory.systemTemp.createTemp('waffra-m481-suffix-');
  store=WaffraEncryptedStore.openAt(
   File('${directory.path}/secure.sqlite'),
   key:'m481-isolated-disposable-sqlcipher-test');
  await WaffraFreshEncryptedVaultBootstrap(
   store:store,experimentalEnabled:true).initialize(
    decision:WaffraFirstRunDecision.freshCandidate);
  await WaffraAccountsSchema.install(store);
  await WaffraAccountContextSchema.install(store);
  accounts=WaffraAccountsRepository(db:store,experimentalEnabled:true);
  context=WaffraAccountContextRepository(store:store,experimentalEnabled:true);
  await accounts.createAccount(id:'bank-1',name:'First bank',
   kind:'bank',openingMinor:125000,createdIso:timestamp,userConfirmed:true);
  await accounts.createAccount(id:'cash-1',name:'Cash',
   kind:'cash',openingMinor:50000,createdIso:timestamp,userConfirmed:true);
 });
 tearDown(()async{
  await store.close();
  if(await directory.exists())await directory.delete(recursive:true);
 });

 test('M481 reads only saved verified bank suffix and supports correction',()async{
  expect(await context.verifiedBankSuffix('bank-1'),isNull);
  expect(await context.verifiedBankSuffix('cash-1'),isNull);
  await context.setVerifiedBankSuffix(accountId:'bank-1',
   lastFour:'1234',confirmedIso:timestamp,userConfirmed:true);
  expect(await context.verifiedBankSuffix('bank-1'),'1234');
  await context.setVerifiedBankSuffix(accountId:'bank-1',
   lastFour:'5678',confirmedIso:timestamp,userConfirmed:true);
  expect(await context.verifiedBankSuffix('bank-1'),'5678');
  expect((await context.inferSmsAccount(
   const WaffraBankSmsFacts(kind:WaffraBankOperationKind.expense,
    sourceSuffix:'5678'))).accountId,'bank-1');
  expect((await context.inferSmsAccount(
   const WaffraBankSmsFacts(kind:WaffraBankOperationKind.expense,
    sourceSuffix:'1234'))).accountId,isNull);
  expect({for(final a in await accounts.balances())a.id:a.balanceMinor},
   {'bank-1':125000,'cash-1':50000});
 });

 test('M481 invalid or nonbank suffix never replaces a verified mapping',()async{
  await context.setVerifiedBankSuffix(accountId:'bank-1',
   lastFour:'1234',confirmedIso:timestamp,userConfirmed:true);
  await expectLater(context.setVerifiedBankSuffix(accountId:'bank-1',
   lastFour:'12A4',confirmedIso:timestamp,userConfirmed:true),
   throwsA(isA<ArgumentError>()));
  await expectLater(context.setVerifiedBankSuffix(accountId:'cash-1',
   lastFour:'9999',confirmedIso:timestamp,userConfirmed:true),
   throwsA(isA<StateError>()));
  expect(await context.verifiedBankSuffix('bank-1'),'1234');
  expect(await context.verifiedBankSuffix('cash-1'),isNull);
 });

 test('M481 rename and suffix source have no financial debit side effects',()async{
  await accounts.renameAccount(id:'bank-1',name:'Renamed bank',
   userConfirmed:true);
  await context.setVerifiedBankSuffix(accountId:'bank-1',
   lastFour:'9012',confirmedIso:timestamp,userConfirmed:true);
  final bank=(await accounts.balances()).singleWhere((a)=>a.id=='bank-1');
  expect(bank.name,'Renamed bank');
  expect(bank.balanceMinor,125000);
  expect(await context.verifiedBankSuffix('bank-1'),'9012');
 });

 test('M481 production code uses witnessed atomic rename and verified reads',(){
  final adapter=File('lib/storage/waffra_verified_accounts_api.dart')
   .readAsStringSync();
  final manager=File('lib/waffra_accounts_manager_page.dart')
   .readAsStringSync();
  final settings=File('lib/waffra_account_context_settings.dart')
   .readAsStringSync();
  expect(adapter,contains('renameAccountWithSuffix({'));
  final write=adapter.substring(adapter.indexOf('renameAccountWithSuffix({'));
  expect(write,contains('_commit<void>((repository)async{'));
  expect(write,contains('await repository.renameAccount('));
  expect(write,contains('.setVerifiedBankSuffix('));
  expect(adapter,contains('readVerifiedAccountMetadata('));
  expect(manager,contains('waffra-account-edit-last-four'));
  expect(manager,contains('verifiedBankSuffix(item.id)'));
  expect(settings,contains('m481-bank-suffix-editor'));
  expect(settings,contains('suffixLoading'));
  expect(settings,contains('lookupRevision'));
 });
}
