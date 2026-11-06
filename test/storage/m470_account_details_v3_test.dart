import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_secure_backup.dart';
import 'package:waffra/storage/waffra_account_details_schema.dart';
import 'package:waffra/storage/waffra_accounts_portable_backup_v3.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_receipt_vault.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_portable_encrypted_backup_exporter.dart';

void main(){
 late Directory dir;
 late WaffraEncryptedStore source;
 const password='m470-account-type-v3-test-protected-password';
 const at='2026-11-06T03:00:00';

 setUp(()async{
  dir=await Directory.systemTemp.createTemp('m470-subtype-v3-');
  source=WaffraEncryptedStore.openAt(
   File('${dir.path}/source.sqlite'),
   key:'m470-subtype-source-disposable-sqlcipher-test-key');
  await WaffraFreshEncryptedVaultBootstrap(
   store:source,experimentalEnabled:true,
  ).initialize(decision:WaffraFirstRunDecision.freshCandidate);
  await WaffraAtomicFinanceSnapshot(
   store:source,experimentalEnabled:true).initializeEmpty();
  await WaffraAccountsSchema.install(source);
  final repo=WaffraAccountsRepository(db:source,experimentalEnabled:true);
  await repo.createAccount(id:'rajhi',name:'مصرف الراجحي - الجاري',
   kind:'bank',openingMinor:100000,createdIso:at,userConfirmed:true);
  await repo.createAccount(id:'cash',name:'نقدي',kind:'cash',
   openingMinor:30000,createdIso:at,userConfirmed:true);
  await WaffraAccountDetailsSchema.install(source);
  await WaffraAccountDetailsSchema.assign(source,
   accountId:'rajhi',kind:'bank',providerId:'rajhi',subtype:'current',
   confirmedIso:at);
 });

 tearDown(()async{
  await source.close();
  if(await dir.exists())await dir.delete(recursive:true);
 });

 Future<String> encryptedBackup()=>WaffraPortableEncryptedBackupExporter(
  snapshot:WaffraAtomicFinanceSnapshot(
   store:source,experimentalEnabled:true),
  receiptVault:WaffraEncryptedReceiptVault(
   store:source,experimentalEnabled:true),
  writerDirectory:dir,verifySourceUnderLock:()async{},
  experimentalEnabled:true).exportV3(password:password);

 test('M470 typed bank identity and legacy cash survive encrypted V3 roundtrip',()async{
  final archive=await encryptedBackup();
  expect(archive.contains('مصرف الراجحي'),isFalse);
  expect(archive.contains('current'),isFalse);
  final preview=await WaffraAccountsPortableBackupV3.verifyAndPreview(
   encryptedArchive:archive,password:password);
  expect(preview.details?.length,1);
  expect(preview.details?.single['provider_id'],'rajhi');
  final target=WaffraEncryptedStore.openAt(
   File('${dir.path}/restored.sqlite'),
   key:'m470-subtype-restored-disposable-sqlcipher-test-key');
  try{
   await WaffraAccountsPortableBackupV3.restoreToEmptyEncryptedVault(
    encryptedArchive:archive,password:password,disposableStore:target,
    userConfirmed:true,experimentalEnabled:true);
   final accounts=await WaffraAccountsRepository(
    db:target,experimentalEnabled:true).balances();
   final bank=accounts.singleWhere((a)=>a.id=='rajhi');
   expect(bank.providerId,'rajhi');
   expect(bank.subtype,'current');
   expect(bank.balanceMinor,100000);
   final cash=accounts.singleWhere((a)=>a.id=='cash');
   expect(cash.providerId,isNull); // Old untyped rows are valid.
   expect(cash.balanceMinor,30000);
  }finally{await target.close();}
 });

 test('M470 forged provider/subtype identity cannot pass authenticated V3 restore',()async{
  final valid=await encryptedBackup();
  final raw=jsonDecode(
   await WaffraSecureBackup.decrypt(valid,password)) as Map<String,dynamic>;
  final identity=(raw['accountDetailsV1'] as List).single
   as Map<String,dynamic>;
  identity['provider_id']='not-a-bank';
  final forged=await WaffraSecureBackup.encryptUserBackup(
   jsonEncode(raw),password);
  await expectLater(WaffraAccountsPortableBackupV3.verifyAndPreview(
   encryptedArchive:forged,password:password),
   throwsA(isA<FormatException>()));
 });

 test('M470 archived bank identity survives V3 without reactivation',()async{
  final repo=WaffraAccountsRepository(db:source,experimentalEnabled:true);
  await repo.createAccount(id:'old-bank',name:'Old savings',
   kind:'bank',openingMinor:0,createdIso:at,userConfirmed:true);
  await WaffraAccountDetailsSchema.assign(source,
   accountId:'old-bank',kind:'bank',providerId:'inma',
   subtype:'savings',confirmedIso:at);
  await repo.archiveEmptyAccount(id:'old-bank',userConfirmed:true);
  final encrypted=await encryptedBackup();
  final target=WaffraEncryptedStore.openAt(
   File('${dir.path}/archived-restore.sqlite'),
   key:'m470-archived-restored-disposable-sqlcipher-test-key');
  try{
   await WaffraAccountsPortableBackupV3.restoreToEmptyEncryptedVault(
    encryptedArchive:encrypted,password:password,disposableStore:target,
    userConfirmed:true,experimentalEnabled:true);
   final restored=await WaffraAccountsRepository(
    db:target,experimentalEnabled:true).balances();
   final old=restored.singleWhere((a)=>a.id=='old-bank');
   expect(old.archived,isTrue);
   expect(old.kind,'bank');
   expect(old.providerId,'inma');
   expect(old.subtype,'savings');
   expect(old.balanceMinor,0);
  }finally{await target.close();}
 });

 test('M470 unsupported bank/provider combinations are rejected',()async{
  expect(WaffraAccountDetailsSchema.valid(
   kind:'bank',providerId:'none',subtype:'current'),isFalse);
  expect(WaffraAccountDetailsSchema.valid(
   kind:'bank',providerId:'rajhi',subtype:'prepaid'),isFalse);
  expect(WaffraAccountDetailsSchema.valid(
   kind:'bank',providerId:'rajhi',subtype:'savings'),isTrue);
  await expectLater(WaffraAccountDetailsSchema.assign(source,
   accountId:'cash',kind:'bank',providerId:'rajhi',
   subtype:'current',confirmedIso:at),
   throwsStateError);
 });
}
