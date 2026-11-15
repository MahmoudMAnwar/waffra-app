import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_account_context_schema.dart';
import 'package:waffra/storage/waffra_account_context_repository.dart';

void main(){
 late Directory dir;
 late WaffraEncryptedStore db;
 const at='2026-11-14T21:40:00Z';
 setUp(()async{
  dir=await Directory.systemTemp.createTemp('m943-bank-suffix-');
  db=WaffraEncryptedStore.openAt(
   File('${dir.path}/money.sqlite'),
   key:'m943-disposable-suffix-encryption-only');
  await WaffraFreshEncryptedVaultBootstrap(
   store:db,experimentalEnabled:true).initialize(
    decision:WaffraFirstRunDecision.freshCandidate);
  await WaffraAtomicFinanceSnapshot(
   store:db,experimentalEnabled:true).initializeEmpty();
  await WaffraAccountsSchema.install(db);
  await WaffraAccountContextSchema.install(db);
  await WaffraAccountsRepository(db:db,experimentalEnabled:true)
   .createAccount(id:'bank',name:'حساب جاري',kind:'bank',
    openingMinor:250000,createdIso:at,userConfirmed:true);
 });
 tearDown(()async{
  await db.close();
  await dir.delete(recursive:true);
 });
 test('M943 confirmed removal deletes suffix only, not opening or income',()async{
  final api=WaffraAccountContextRepository(store:db,experimentalEnabled:true);
  await api.setVerifiedBankSuffix(
   accountId:'bank',lastFour:'1234',confirmedIso:at,userConfirmed:true);
  expect(await api.verifiedBankSuffix('bank'),'1234');
  await expectLater(api.clearVerifiedBankSuffix(
   accountId:'bank',confirmedIso:at,userConfirmed:false),
   throwsStateError);
  expect(await api.verifiedBankSuffix('bank'),'1234');
  await api.clearVerifiedBankSuffix(
   accountId:'bank',confirmedIso:at,userConfirmed:true);
  expect(await api.verifiedBankSuffix('bank'),isNull);
  expect((await WaffraAccountsRepository(db:db,experimentalEnabled:true)
   .balances()).single.balanceMinor,250000);
  final n=(await db.customSelect(
   'SELECT COUNT(*) AS count FROM fresh_finance_entries').getSingle())
   .read<int>('count');
  expect(n,0);
  await db.close();
  db=WaffraEncryptedStore.openAt(
   File('${dir.path}/money.sqlite'),
   key:'m943-disposable-suffix-encryption-only');
  expect(await WaffraAccountContextRepository(
   store:db,experimentalEnabled:true).verifiedBankSuffix('bank'),isNull);
 });
}
