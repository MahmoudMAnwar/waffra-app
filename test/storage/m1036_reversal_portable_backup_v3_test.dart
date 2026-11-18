import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_accounts_portable_backup_v3.dart';
import 'package:waffra/storage/waffra_account_context_repository.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_receipt_vault.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_portable_encrypted_backup_exporter.dart';

/// Restore is executed only into an empty throwaway encrypted test vault.
void main(){
 late Directory directory;
 late WaffraEncryptedStore source;
 const secret='m1036-v3-disposable-source-key-32-characters-long';
 const password='m1036-test-only-v3-password';
 const occurred='2026-11-18T09:15:00';
 const corrected='2026-11-18T10:15:00';
 String reversalId(String id)=>'reversal-'+sha256.convert(utf8.encode(id)).toString();
 WaffraAtomicFinanceSnapshot snapshot(WaffraEncryptedStore store)=>
  WaffraAtomicFinanceSnapshot(store:store,experimentalEnabled:true);
 WaffraAccountsRepository repo(WaffraEncryptedStore store)=>
  WaffraAccountsRepository(db:store,experimentalEnabled:true);
 Future<Map<String,int>> balances(WaffraEncryptedStore store)async=>
  {for(final a in await repo(store).balances())a.id:a.balanceMinor};
 Future<String> exportV3()=>
  WaffraPortableEncryptedBackupExporter(
   snapshot:snapshot(source),
   receiptVault:WaffraEncryptedReceiptVault(
    store:source,experimentalEnabled:true),
   writerDirectory:directory,
   verifySourceUnderLock:()async{},
   experimentalEnabled:true,
  ).exportV3(password:password);
 Future<WaffraEncryptedStore> restore(String archive,String name)async{
  final destination=WaffraEncryptedStore.openAt(
   File(directory.path+'/'+name+'.sqlite'),
   key:'m1036-destination-disposable-new-key-'+name);
  try{
   await WaffraAccountsPortableBackupV3.restoreToEmptyEncryptedVault(
    encryptedArchive:archive,password:password,disposableStore:destination,
    userConfirmed:true,experimentalEnabled:true);
   return destination;
  }catch(_){
   await destination.close();
   rethrow;
  }
 }

 setUp(()async{
  directory=await Directory.systemTemp.createTemp('waffra-m1036-v3');
  source=WaffraEncryptedStore.openAt(
   File(directory.path+'/source.sqlite'),key:secret);
  await WaffraFreshEncryptedVaultBootstrap(
   store:source,experimentalEnabled:true,
  ).initialize(decision:WaffraFirstRunDecision.freshCandidate);
  await snapshot(source).initializeEmpty();
  await WaffraAccountsSchema.install(source);
  await repo(source).createAccount(id:'a',name:'Source account',
   kind:'bank',openingMinor:50000,createdIso:occurred,userConfirmed:true);
  await repo(source).createAccount(id:'b',name:'Target account',
   kind:'wallet',openingMinor:25000,createdIso:occurred,userConfirmed:true);
  await repo(source).transfer(id:'original',
   fromAccountId:'a',toAccountId:'b',
   amountMinor:12500,occurredIso:occurred,userConfirmed:true);
 });
 tearDown(()async{
  await source.close();
  if(await directory.exists())await directory.delete(recursive:true);
 });

 test('M1036 V3 restores both original and reversal without extra money',()async{
  await repo(source).reverseInternalTransfer(
   originalTransferId:'original',reversedIso:corrected,userConfirmed:true);
  final archive=await exportV3();
  expect(archive.contains('Source account'),isFalse);
  final preview=await WaffraAccountsPortableBackupV3.verifyAndPreview(
   encryptedArchive:archive,password:password);
  expect(preview.accounts.length,2);
  expect(preview.transfers.length,2);
  final destination=await restore(archive,'after-reversal');
  try{
   expect(await balances(destination),{'a':50000,'b':25000});
   final events=await WaffraAccountContextRepository(
    store:destination,experimentalEnabled:true)
    .readInternalTransferHistory();
   expect(events.length,2);
   expect(events.singleWhere((x)=>x.id=='original').reversalId,
    reversalId('original'));
   expect(events.singleWhere((x)=>x.isReversal).originalTransferId,'original');
   expect(await repo(destination).reverseInternalTransfer(
    originalTransferId:'original',reversedIso:'2026-11-18T11:15:00',
    userConfirmed:true),isFalse);
   expect(await balances(destination),{'a':50000,'b':25000});
   final entries=await destination.customSelect(
    'SELECT COUNT(*) AS n FROM fresh_finance_entries').getSingle();
   expect(entries.read<int>('n'),0);
  }finally{await destination.close();}
 });

 test('M1036 backup made before correction restores without false reversed tag',()async{
  final archive=await exportV3();
  final preview=await WaffraAccountsPortableBackupV3.verifyAndPreview(
   encryptedArchive:archive,password:password);
  expect(preview.transfers.length,1);
  final destination=await restore(archive,'before-reversal');
  try{
   final history=WaffraAccountContextRepository(
    store:destination,experimentalEnabled:true);
   final before=(await history.readInternalTransferHistory()).single;
   expect(before.id,'original');
   expect(before.isReversed,isFalse);
   expect(before.reversalId,isNull);
   expect(await balances(destination),{'a':37500,'b':37500});
   expect(await repo(destination).reverseInternalTransfer(
    originalTransferId:'original',reversedIso:corrected,
    userConfirmed:true),isTrue);
   expect((await history.readInternalTransferHistory())
    .singleWhere((x)=>x.id=='original').isReversed,isTrue);
   expect(await balances(destination),{'a':50000,'b':25000});
  }finally{await destination.close();}
 });
}
