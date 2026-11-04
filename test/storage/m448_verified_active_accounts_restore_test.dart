import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_accounts_portable_backup_v3.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_receipt_vault.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_portable_backup_v2.dart';
import 'package:waffra/storage/waffra_portable_encrypted_backup_exporter.dart';
import 'package:waffra/storage/waffra_verified_active_accounts_restore.dart';

void main(){
 late Directory dir;
 late WaffraEncryptedStore live;
 late WaffraEncryptedStore target;
 const pass='m448-restoration-password-verified-12+';
 const timestamp='2026-11-04T13:20:00Z';
 WaffraAtomicFinanceSnapshot state(WaffraEncryptedStore store)=>
  WaffraAtomicFinanceSnapshot(store:store,experimentalEnabled:true);

 Future<void> setupSource(WaffraEncryptedStore store,String name,int balance)async{
  await WaffraFreshEncryptedVaultBootstrap(
   store:store,experimentalEnabled:true,
  ).initialize(decision:WaffraFirstRunDecision.freshCandidate);
  await state(store).initializeEmpty();
  await WaffraAccountsSchema.install(store);
  await WaffraAccountsRepository(db:store,experimentalEnabled:true)
   .createAccount(id:name,name:name,kind:'bank',openingMinor:balance,
    createdIso:timestamp,userConfirmed:true);
 }
 Future<String> export(WaffraEncryptedStore store) =>
  WaffraPortableEncryptedBackupExporter(
   snapshot:state(store),receiptVault:WaffraEncryptedReceiptVault(
    store:store,experimentalEnabled:true),
   writerDirectory:dir,verifySourceUnderLock:()async{},
   experimentalEnabled:true,
  ).exportV3(password:pass);

 Future<({String incoming,String rescue,String checksum})> archives()async{
  final rescue=await export(live);
  final incoming=await export(target);
  final preview=await WaffraAccountsPortableBackupV3.verifyAndPreview(
   encryptedArchive:incoming,password:pass);
  final finance=await WaffraPortableBackupV2.verifyAndPreview(
   encryptedArchive:preview.encryptedV2,password:pass);
  return (incoming:incoming,rescue:rescue,checksum:finance.sourceChecksum);
 }

 setUp(()async{
  dir=await Directory.systemTemp.createTemp('m448-live-restore-');
  live=WaffraEncryptedStore.openAt(File('${dir.path}/live.sqlite'),
   key:'m448-live-sqlcipher-key-from-disposable-fixture');
  target=WaffraEncryptedStore.openAt(File('${dir.path}/archive.sqlite'),
   key:'m448-archive-independent-fixture-key');
  await setupSource(live,'old-account',100000);
  await setupSource(target,'new-account',300000);
 });
 tearDown(()async{
  await live.close();await target.close();
  if(await dir.exists())await dir.delete(recursive:true);
 });

 Future<WaffraVerifiedAccountsRestoreReceipt> apply(
  ({String incoming,String rescue,String checksum}) p,{
  bool saved=true,int? expectedGeneration,
 }) async {
  final before=await state(live).read();
  return WaffraVerifiedActiveAccountsRestore(
   store:live,snapshot:state(live),experimentalEnabled:true,
  ).restore(
   encryptedArchive:p.incoming,password:pass,
   savedRescueArchive:p.rescue,rescuePassword:pass,
   expectedGeneration:expectedGeneration??before.generation,
   expectedDigest:before.digest,preflightChecksum:p.checksum,
   userConfirmed:true,externallySavedRescueConfirmed:saved,
  );
 }

 Future<Map<String,int>> balances()async=>
  {for(final a in await WaffraAccountsRepository(
    db:live,experimentalEnabled:true).balances())a.id:a.balanceMinor};

 test('authenticated V3 replaces accounts atomically and advances revision',()async{
  final p=await archives();
  final before=(await state(live).read()).generation;
  final receipt=await apply(p);
  expect(receipt.previousGeneration,before);
  expect(receipt.newGeneration,greaterThan(before));
  expect(await balances(),{'new-account':300000});
  final after=await state(live).read();
  expect(after.generation,receipt.newGeneration);
  expect((await live.customSelect('PRAGMA foreign_key_check').get()),isEmpty);
 });

 test('missing external rescue refuses any active money mutation',()async{
  final p=await archives();
  await expectLater(apply(p,saved:false),throwsA(isA<StateError>()));
  expect(await balances(),{'old-account':100000});
 });

 test('stale source witness refuses replacement',()async{
  final p=await archives();
  final stateBefore=await state(live).read();
  await state(live).commit(expectedGeneration:stateBefore.generation,
   fullFinanceSnapshot:stateBefore.values);
  await expectLater(apply(p,expectedGeneration:stateBefore.generation),
   throwsA(isA<StateError>()));
  expect(await balances(),{'old-account':100000});
 });

 test('unsupported retained SQL records refuse replacement',()async{
  final p=await archives();
  await live.customStatement(
   'INSERT INTO fresh_finance_settings(setting_key,value_json) VALUES (?,?)',
   ['unbacked-protected','{}']);
  await expectLater(apply(p),throwsA(isA<StateError>()));
  expect(await balances(),{'old-account':100000});
  expect((await live.customSelect(
   "SELECT count(*) AS n FROM fresh_finance_settings").getSingle())
   .read<int>('n'),1);
 });
}
