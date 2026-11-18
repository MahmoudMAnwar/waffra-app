import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_account_context_repository.dart';
import 'package:waffra/storage/waffra_account_context_schema.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

/// Synthetic accounts and a disposable SQLCipher database only.
void main(){
 late Directory directory;
 late WaffraEncryptedStore db;
 late WaffraAccountsRepository accounts;
 late WaffraAccountContextRepository history;
 const secret='m1036-disposable-qa-key-only';
 const firstAt='2026-11-18T08:00:00';
 const reverseAt='2026-11-18T09:00:00';
 String reversalId(String id)=>'reversal-'+sha256.convert(utf8.encode(id)).toString();
 Future<Map<String,int>> balances()async=>{for(final a in await accounts.balances())a.id:a.balanceMinor};
 Future<int> count(String table)async=>
  (await db.customSelect('SELECT COUNT(*) AS n FROM '+table).getSingle())
   .read<int>('n');
 Future<void> createTransfer({String id='original',String at=firstAt})async{
  expect(await accounts.transfer(id:id,fromAccountId:'a',toAccountId:'b',
   amountMinor:12500,occurredIso:at,userConfirmed:true),isTrue);
 }
 setUp(()async{
  directory=await Directory.systemTemp.createTemp('waffra-m1036-reversal');
  db=WaffraEncryptedStore.openAt(File(directory.path+'/finance.sqlite'),key:secret);
  await WaffraFreshEncryptedVaultBootstrap(store:db,experimentalEnabled:true)
   .initialize(decision:WaffraFirstRunDecision.freshCandidate);
  await WaffraAccountsSchema.install(db);
  await WaffraAccountContextSchema.install(db);
  accounts=WaffraAccountsRepository(db:db,experimentalEnabled:true);
  history=WaffraAccountContextRepository(store:db,experimentalEnabled:true);
  await accounts.createAccount(id:'a',name:'Sender bank',
   kind:'bank',openingMinor:50000,createdIso:firstAt,userConfirmed:true);
  await accounts.createAccount(id:'b',name:'Recipient wallet',
   kind:'wallet',openingMinor:25000,createdIso:firstAt,userConfirmed:true);
  await accounts.createAccount(id:'c',name:'Other',
   kind:'cash',openingMinor:10000,createdIso:firstAt,userConfirmed:true);
 });
 tearDown(()async{
  await db.close();
  if(await directory.exists())await directory.delete(recursive:true);
 });

 test('M1036 original and reverse restore both balances and conserve total',()async{
  await createTransfer();
  expect(await balances(),{'a':37500,'b':37500,'c':10000});
  final before=(await history.readInternalTransferHistory()).single;
  expect(before.isReversed,isFalse);
  expect(before.isReversal,isFalse);
  expect(await accounts.reverseInternalTransfer(originalTransferId:'original',
   reversedIso:reverseAt,userConfirmed:true),isTrue);
  expect(await balances(),{'a':50000,'b':25000,'c':10000});
  final rows=await history.readInternalTransferHistory();
  expect(rows.length,2);
  final original=rows.singleWhere((r)=>r.id=='original');
  final reverse=rows.singleWhere((r)=>r.id==reversalId('original'));
  expect(original.isReversed,isTrue);
  expect(original.reversalId,reverse.id);
  expect(original.isReversal,isFalse);
  expect(reverse.isReversal,isTrue);
  expect(reverse.originalTransferId,'original');
  expect(reverse.fromAccountId,'b');
  expect(reverse.toAccountId,'a');
  expect(reverse.amountMinor,12500);
  expect(await count('fresh_finance_entries'),0);
  expect(await count('fresh_finance_internal_transfers'),2);
  expect((await balances()).values.reduce((a,b)=>a+b),85000);
 });

 test('M1036 repeated and unauthorised reverse never doubles money',()async{
  await createTransfer();
  await expectLater(accounts.reverseInternalTransfer(
   originalTransferId:'original',reversedIso:reverseAt,
   userConfirmed:false),throwsA(isA<StateError>()));
  expect(await count('fresh_finance_internal_transfers'),1);
  expect(await accounts.reverseInternalTransfer(
   originalTransferId:'original',reversedIso:reverseAt,
   userConfirmed:true),isTrue);
  expect(await accounts.reverseInternalTransfer(
   originalTransferId:'original',reversedIso:'2026-11-18T10:00:00',
   userConfirmed:true),isFalse);
  await expectLater(accounts.reverseInternalTransfer(
   originalTransferId:reversalId('original'),reversedIso:reverseAt,
   userConfirmed:true),throwsA(isA<StateError>()));
  expect(await count('fresh_finance_internal_transfers'),2);
  expect(await balances(),{'a':50000,'b':25000,'c':10000});
 });

 test('M1036 both account filters show linked original and compensation',()async{
  await createTransfer();
  await accounts.reverseInternalTransfer(
   originalTransferId:'original',reversedIso:reverseAt,userConfirmed:true);
  for(final id in ['a','b']){
   final rows=await history.readInternalTransferHistory(accountId:id);
   expect(rows.length,2,reason:id);
   expect(rows.singleWhere((r)=>r.id=='original').isReversed,isTrue);
   expect(rows.singleWhere((r)=>r.isReversal).originalTransferId,'original');
  }
  expect(await history.readInternalTransferHistory(accountId:'c'),isEmpty);
 });

 test('M1036 a compensation outside current history page still marks original',()async{
  await createTransfer();
  await accounts.reverseInternalTransfer(originalTransferId:'original',
   reversedIso:'2026-11-17T01:00:00',userConfirmed:true);
  final page=await history.readInternalTransferHistory(limit:1);
  expect(page.length,1);
  expect(page.single.id,'original');
  expect(page.single.isReversed,isTrue);
  expect(page.single.reversalId,reversalId('original'));
 });

 test('M1036 account balances and linkage survive SQLCipher cold reopen',()async{
  await createTransfer();
  await accounts.reverseInternalTransfer(
   originalTransferId:'original',reversedIso:reverseAt,userConfirmed:true);
  await db.close();
  db=WaffraEncryptedStore.openAt(File(directory.path+'/finance.sqlite'),key:secret);
  await WaffraAccountsSchema.requireReady(db);
  accounts=WaffraAccountsRepository(db:db,experimentalEnabled:true);
  history=WaffraAccountContextRepository(store:db,experimentalEnabled:true);
  final rows=await history.readInternalTransferHistory();
  expect(rows.singleWhere((x)=>x.id=='original').isReversed,isTrue);
  expect(rows.singleWhere((x)=>x.isReversal).originalTransferId,'original');
  expect(await balances(),{'a':50000,'b':25000,'c':10000});
  expect(await count('fresh_finance_internal_transfers'),2);
 });

 test('M1036 corrupted link note is refused, never presented as reversed',()async{
  await createTransfer();
  await accounts.reverseInternalTransfer(
   originalTransferId:'original',reversedIso:reverseAt,userConfirmed:true);
  await db.customStatement(
   'UPDATE fresh_finance_internal_transfers SET note=? WHERE transfer_id=?',
   ['different-original',reversalId('original')]);
  await expectLater(history.readInternalTransferHistory(),
   throwsA(isA<StateError>()));
  expect(await count('fresh_finance_internal_transfers'),2);
 });

 test('M1036 forged reversal amount fails financial pairing check',()async{
  await createTransfer();
  await accounts.reverseInternalTransfer(
   originalTransferId:'original',reversedIso:reverseAt,userConfirmed:true);
  await db.customStatement(
   'UPDATE fresh_finance_internal_transfers SET amount_minor=? WHERE transfer_id=?',
   [1,reversalId('original')]);
  await expectLater(history.readInternalTransferHistory(),
   throwsA(isA<StateError>()));
 });

 test('M1036 same-account source and destination are denied',()async{
  await expectLater(accounts.transfer(id:'bad',
   fromAccountId:'a',toAccountId:'a',amountMinor:12500,
   occurredIso:firstAt,userConfirmed:true),throwsA(isA<ArgumentError>()));
  expect(await count('fresh_finance_internal_transfers'),0);
  expect(await balances(),{'a':50000,'b':25000,'c':10000});
 });

 test('M1036 review UI links pairs, previews accounts and refreshes modal',(){
  final ui=File('lib/waffra_home_verified_transfer_cards.part.dart')
   .readAsStringSync();
  expect(ui,contains('if(!t.isReversal&&!t.isReversed)'));
  expect(ui,contains("'تم عكس التحويل'"));
  expect(ui,contains("Key('m1036-related-transfer-'"));
  expect(ui,contains('onOpenRelated:(id){'));
  expect(ui,contains('StatefulBuilder('));
  expect(ui,contains('setSheetState(()=>future=_m648HomeTransfers(selected))'));
  expect(ui,contains('api.balances()'));
  expect(ui,contains('cash(restoredFrom/100)'));
  expect(ui,contains('cash(debitedTo/100)'));
  expect(ui,contains('ليس استردادًا فعليًا من البنك'));
  expect(ui,contains('_m648InvalidateTransfers();'));
  expect(ui,contains('await _m467RefreshHomeAccounts();'));
  expect(ui,contains('api.reverseInternalTransfer('));
  // Commit succeeded before the refresh attempt: reporting "not saved"
  // would be a dangerous false negative and invite an unnecessary retry.
  expect(ui,contains('catch(refreshError)'));
  expect(ui,contains('تم حفظ عكس التحويل، لكن تعذر التحقق من تحديث الأرصدة'));
  expect(ui,contains('final expectedFrom=reversed?restoredFrom:from.balanceMinor'));
  expect(ui,contains('final expectedTo=reversed?debitedTo:to.balanceMinor'));
  expect(ui,contains('sourceAfter.single.balanceMinor==expectedFrom'));
  expect(ui,contains('targetAfter.single.balanceMinor==expectedTo'));
  expect(ui,contains('verifiedAfterRefresh=ledgerMatches&&_m468VerifiedAccountsLoaded'));
  expect(ui,contains('displayedFrom.single.balanceMinor==expectedFrom'));
  expect(ui,contains('displayedTo.single.balanceMinor==expectedTo'));
  expect(ui,contains('حدّث السجل قبل إعادة المحاولة'));
 });
}
