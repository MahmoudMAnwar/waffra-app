import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_backup_guard.dart';

void main(){
 late Directory dir;
 late WaffraEncryptedStore db;
 const key='m440-verified-backup-test-disposable-key';
 Future<void> bootstrap()async{
  await WaffraFreshEncryptedVaultBootstrap(store:db,experimentalEnabled:true)
   .initialize(decision:WaffraFirstRunDecision.freshCandidate);
 }
 setUp(()async{
  dir=await Directory.systemTemp.createTemp('waffra-m440-backup');
  db=WaffraEncryptedStore.openAt(File(dir.path+'/test.sqlite'),key:key);
 });
 tearDown(()async{
  await db.close();
  if(await dir.exists())await dir.delete(recursive:true);
 });
 test('M440 V2 backup supports absence or empty versioned account schema',()async{
  await bootstrap();
  await WaffraAccountsPortableV2Guard.refuseUnrestorableAccounts(db);
  await WaffraAccountsSchema.install(db);
  await WaffraAccountsPortableV2Guard.refuseUnrestorableAccounts(db);
 });
 test('M440 even a single account requires account-aware backup and restore',()async{
  await bootstrap();
  await WaffraAccountsSchema.install(db);
  await WaffraAccountsRepository(db:db,experimentalEnabled:true).createAccount(
   id:'cash',name:'My cash',kind:'cash',openingMinor:0,
   createdIso:'2026-11-03T18:00:00',userConfirmed:true);
  await expectLater(
   WaffraAccountsPortableV2Guard.refuseUnrestorableAccounts(db),
   throwsA(isA<StateError>()));
 });
 test('M440 partial account schema never becomes an apparently clean backup',()async{
  await bootstrap();
  await db.customStatement('CREATE TABLE fresh_finance_money_accounts (id TEXT PRIMARY KEY)');
  await expectLater(
   WaffraAccountsPortableV2Guard.refuseUnrestorableAccounts(db),
   throwsA(isA<StateError>()));
 });
 test('M440 account schema corruption prevents a partial V2 export',()async{
  await bootstrap();
  await WaffraAccountsSchema.install(db);
  await db.customStatement('DROP TABLE fresh_finance_internal_transfers');
  await expectLater(
   WaffraAccountsPortableV2Guard.refuseUnrestorableAccounts(db),
   throwsA(isA<StateError>()));
 });
}
