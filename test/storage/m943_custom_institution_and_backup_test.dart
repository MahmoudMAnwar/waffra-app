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
import 'package:waffra/storage/waffra_encrypted_receipt_vault.dart';
import 'package:waffra/storage/waffra_portable_encrypted_backup_exporter.dart';
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
 test('M943 custom institution root cannot archive while a child is live',()async{
  await bank('root-other',0,'other');
  await bank('child-other',250000,'other');
  await WaffraCustomInstitutionLinks.assign(db,
   accountId:'child-other',rootAccountId:'root-other',
   confirmedIso:at,userConfirmed:true);
  await expectLater(accounts().archiveEmptyAccount(
   id:'root-other',userConfirmed:true),throwsStateError);
  final current=await accounts().balances();
  expect(current.singleWhere((a)=>a.id=='root-other').archived,isFalse);
  expect(current.singleWhere((a)=>a.id=='child-other').balanceMinor,250000);
 });

 test('M943 original encrypted V3 envelope restores custom Other group atomically',()async{
  await bank('owner-root',500000,'other');
  await bank('child-savings',200000,'other');
  await WaffraCustomInstitutionLinks.assign(db,
   accountId:'child-savings',rootAccountId:'owner-root',
   confirmedIso:at,userConfirmed:true);
  const password='m943-disposable-backup-archive-password';
  final archive=await WaffraPortableEncryptedBackupExporter(
   snapshot:WaffraAtomicFinanceSnapshot(
    store:db,experimentalEnabled:true),
   receiptVault:WaffraEncryptedReceiptVault(
    store:db,experimentalEnabled:true),
   writerDirectory:dir,verifySourceUnderLock:()async{},
   experimentalEnabled:true).exportV3(password:password);
  final preview=await WaffraAccountsPortableBackupV3.verifyAndPreview(
   encryptedArchive:archive,password:password);
  expect(preview.customInstitutionLinks?.single['root_account_id'],'owner-root');
  final target=WaffraEncryptedStore.openAt(
   File('${dir.path}/restored-v3.sqlite'),
   key:'m943-custom-institution-restored-test-only');
  try{
   await WaffraAccountsPortableBackupV3.restoreToEmptyEncryptedVault(
    encryptedArchive:archive,password:password,disposableStore:target,
    userConfirmed:true,experimentalEnabled:true);
   final restored=await WaffraAccountsRepository(
    db:target,experimentalEnabled:true).balances();
   expect(restored.fold<int>(0,(v,a)=>v+a.balanceMinor),700000);
   expect(restored.singleWhere((a)=>a.id=='child-savings')
    .customInstitutionRootId,'owner-root');
   expect(WaffraRecurringAccountGroups.fromAccounts(restored)
    .singleWhere((g)=>g.id=='bank:account:owner-root')
    .accounts.length,2);
   final n=(await target.customSelect(
    'SELECT COUNT(*) AS n FROM fresh_finance_entries').getSingle())
    .read<int>('n');
   expect(n,0);
  }finally{await target.close();}
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
