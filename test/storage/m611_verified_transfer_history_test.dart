import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_account_context_repository.dart';
import 'package:waffra/storage/waffra_account_context_schema.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

void main() {
 late Directory directory;
 late WaffraEncryptedStore db;
 late WaffraAccountsRepository accounts;
 late WaffraAccountContextRepository context;
 const at='2026-11-09T09:30:00';

 setUp(() async {
  directory=await Directory.systemTemp.createTemp('m611-verified-transfers');
  db=WaffraEncryptedStore.openAt(File('${directory.path}/source.sqlite'),
   key:'m611-disposable-verified-test-key-only');
  await WaffraFreshEncryptedVaultBootstrap(
   store:db,experimentalEnabled:true,
  ).initialize(decision:WaffraFirstRunDecision.freshCandidate);
  await WaffraAccountsSchema.install(db);
  await WaffraAccountContextSchema.install(db);
  accounts=WaffraAccountsRepository(db:db,experimentalEnabled:true);
  context=WaffraAccountContextRepository(store:db,experimentalEnabled:true);
  await accounts.createAccount(id:'bank',name:'Bank',
   kind:'bank',openingMinor:100000,createdIso:at,userConfirmed:true);
  await accounts.createAccount(id:'cash',name:'Cash',
   kind:'cash',openingMinor:1000,createdIso:at,userConfirmed:true);
  await accounts.createAccount(id:'wallet',name:'Wallet',
   kind:'wallet',openingMinor:0,createdIso:at,userConfirmed:true);
 });

 tearDown(() async {
  await db.close();
  if(await directory.exists())await directory.delete(recursive:true);
 });

 test('M611 read-only SQLCipher history lists the exact committed transfers',() async {
  expect(await context.readInternalTransferHistory(),isEmpty);
  final first=await accounts.transfer(id:'transfer-1',
   fromAccountId:'bank',toAccountId:'cash',amountMinor:12500,
   occurredIso:at,note:'Manual transfer',userConfirmed:true);
  expect(first,isTrue);
  final second=await accounts.transfer(id:'transfer-2',
   fromAccountId:'cash',toAccountId:'wallet',amountMinor:300,
   occurredIso:'2026-11-09T09:31:00',userConfirmed:true);
  expect(second,isTrue);
  final all=await context.readInternalTransferHistory();
  expect(all.map((v)=>v.id).toList(),['transfer-2','transfer-1']);
  expect(all.last.amountMinor,12500);
  expect(all.last.fromAccountId,'bank');
  expect(all.last.toAccountId,'cash');
  expect(all.last.note,'Manual transfer');
  expect((await context.readInternalTransferHistory(accountId:'bank'))
   .map((v)=>v.id).toList(),['transfer-1']);
  expect((await context.readInternalTransferHistory(accountId:'wallet'))
   .map((v)=>v.id).toList(),['transfer-2']);
  expect((await context.readInternalTransferHistory(accountId:'cash'))
   .length,2);
  expect((await context.readInternalTransferHistory(limit:1)).length,1);
  expect({for(final a in await accounts.balances())a.id:a.balanceMinor},
   {'bank':87500,'cash':13200,'wallet':300});
  final ledger=await db.customSelect(
   'SELECT count(*) AS total FROM fresh_finance_entries').getSingle();
  expect(ledger.read<int>('total'),0,
   reason:'Internal transfers must never create income/expense rows');
 });

 test('M611 unsafe history limits rejected and reading cannot change balances',() async {
  final before={for(final a in await accounts.balances())a.id:a.balanceMinor};
  await expectLater(context.readInternalTransferHistory(limit:0),
   throwsArgumentError);
  await expectLater(context.readInternalTransferHistory(limit:501),
   throwsArgumentError);
  expect(await context.readInternalTransferHistory(accountId:'cash'),isEmpty);
  expect({for(final a in await accounts.balances())a.id:a.balanceMinor},before);
 });
}
