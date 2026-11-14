import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_account_details_schema.dart';
import 'package:waffra/storage/waffra_custom_institution_links.dart';
import 'package:waffra/storage/waffra_accounts_portable_backup_v3.dart';
import 'package:waffra/waffra_recurring_account_groups.dart';

void main(){
 late Directory dir;
 late WaffraEncryptedStore db;
 const at='2026-11-14T21:40:00Z';
 WaffraAccountsRepository accounts()=>
  WaffraAccountsRepository(db:db,experimentalEnabled:true);
 Future<void> bank(String id,int openingMinor,String provider)async{
  await accounts().createAccount(id:id,name:'مؤسسة $id',
   kind:'bank',openingMinor:openingMinor,createdIso:at,userConfirmed:true);
  await WaffraAccountDetailsSchema.assign(db,
   accountId:id,kind:'bank',providerId:provider,subtype:'current',
   confirmedIso:at);
 }
 setUp(()async{
  dir=await Directory.systemTemp.createTemp('m943-other-bank-');
  db=WaffraEncryptedStore.openAt(File('${dir.path}/money.sqlite'),
   key:'m943-disposable-custom-bank-group-test');
  await WaffraFreshEncryptedVaultBootstrap(
   store:db,experimentalEnabled:true).initialize(
    decision:WaffraFirstRunDecision.freshCandidate);
  await WaffraAtomicFinanceSnapshot(
   store:db,experimentalEnabled:true).initializeEmpty();
  await WaffraAccountsSchema.install(db);
  await WaffraAccountDetailsSchema.install(db);
 });
 tearDown(()async{await db.close();await dir.delete(recursive:true);});
 test('M943 Other institution children stay independent and grouped across reopen',()async{
  await bank('root-other',500000,'other');
  await bank('child-other',200000,'other');
  await bank('different-bank',100000,'rajhi');
  await WaffraCustomInstitutionLinks.assign(db,
   accountId:'child-other',rootAccountId:'root-other',
   confirmedIso:at,userConfirmed:true);
  final current=await accounts().balances();
  final groups=WaffraRecurringAccountGroups.fromAccounts(current);
  final linked=groups.singleWhere((g)=>g.id=='bank:account:root-other');
  expect(linked.accounts.map((a)=>a.id).toSet(),
   {'root-other','child-other'});
  expect(groups.singleWhere((g)=>g.id=='bank:institution:rajhi')
   .accounts.single.id,'different-bank');
  expect(current.fold<int>(0,(sum,a)=>sum+a.balanceMinor),800000);
  final captured=await WaffraAccountsPortableBackupV3.capture(db);
  final links=captured['customInstitutionLinksV1'] as List;
  expect(links.length,1);
  final validated=WaffraCustomInstitutionLinks.validateBackup(links,
   captured['accounts']! as List<Map<String,Object?>>,
   captured['accountDetailsV1']! as List<Map<String,Object?>>);
  expect(validated?.single['root_account_id'],'root-other');
  await db.close();
  db=WaffraEncryptedStore.openAt(File('${dir.path}/money.sqlite'),
   key:'m943-disposable-custom-bank-group-test');
  expect(WaffraRecurringAccountGroups.fromAccounts(await accounts().balances())
   .singleWhere((g)=>g.id=='bank:account:root-other').accounts.length,2);
 });
 test('M943 no guessed cross-provider linkage or unapproved child',()async{
  await bank('root-other',10000,'other');
  await bank('wrong-child',5000,'rajhi');
  await expectLater(WaffraCustomInstitutionLinks.assign(db,
   accountId:'wrong-child',rootAccountId:'root-other',
   confirmedIso:at,userConfirmed:true),throwsStateError);
  expect(await WaffraCustomInstitutionLinks.capture(db),isEmpty);
  await bank('second-other',9000,'other');
  await expectLater(WaffraCustomInstitutionLinks.assign(db,
   accountId:'second-other',rootAccountId:'root-other',
   confirmedIso:at,userConfirmed:false),throwsArgumentError);
  expect(await WaffraCustomInstitutionLinks.capture(db),isEmpty);
 });
}
