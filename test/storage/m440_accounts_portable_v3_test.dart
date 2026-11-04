import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_secure_backup.dart';
import 'package:waffra/storage/waffra_accounts_portable_backup_v3.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_receipt_vault.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_portable_encrypted_backup_exporter.dart';
import 'package:waffra/storage/waffra_unified_finance_writer.dart';

void main(){
 late Directory dir;
 late WaffraEncryptedStore db;
 const key='m440-v3-account-aware-encrypted-disposable-key';
 const password='test-v3-password-protected';
 WaffraAtomicFinanceSnapshot finance(WaffraEncryptedStore store)=>
  WaffraAtomicFinanceSnapshot(store:store,experimentalEnabled:true);
 Future<String> exportV3()async=>WaffraPortableEncryptedBackupExporter(
  snapshot:finance(db),
  receiptVault:WaffraEncryptedReceiptVault(store:db,experimentalEnabled:true),
  writerDirectory:dir,
  verifySourceUnderLock:()async{},
  experimentalEnabled:true,
 ).exportV3(password:password);

 Future<void> seed()async{
  await WaffraFreshEncryptedVaultBootstrap(
   store:db,experimentalEnabled:true,
  ).initialize(decision:WaffraFirstRunDecision.freshCandidate);
  await finance(db).initializeEmpty();
  await WaffraAccountsSchema.install(db);
  final repo=WaffraAccountsRepository(db:db,experimentalEnabled:true);
  await repo.createAccount(
   id:'bank',name:'My bank',kind:'bank',openingMinor:10000,
   createdIso:'2026-11-04T08:00:00',userConfirmed:true);
  await repo.createAccount(
   id:'cash',name:'Cash',kind:'cash',openingMinor:0,
   createdIso:'2026-11-04T08:01:00',userConfirmed:true);
  await WaffraUnifiedFinanceWriter(
   writerDirectory:dir,snapshot:finance(db),experimentalEnabled:true,
  ).appendTransactions(
   records:[<String,Object?>{
    'id':'salary','title':'Salary','category':'Income',
    'amount':50.0,'income':true,'date':'2026-11-04T08:02:00',
    'receiptPath':null,'notes':'','sourceType':'manual',
   }],
   messageHashes:[null],accountId:'bank',userConfirmed:true,
   expectedAccountGeneration:(await finance(db).read()).generation,
  );
  await repo.transfer(
   id:'transfer-1',fromAccountId:'bank',toAccountId:'cash',
   amountMinor:2000,occurredIso:'2026-11-04T08:03:00',
   note:'internal',userConfirmed:true,
  );
 }
 setUp(()async{
  dir=await Directory.systemTemp.createTemp('waffra-m440-v3');
  db=WaffraEncryptedStore.openAt(File('${dir.path}/source.sqlite'),key:key);
 });
 tearDown(()async{
  await db.close();
  if(await dir.exists())await dir.delete(recursive:true);
 });

 test('M440 V3 encrypted archive restores account links and transfers atomically',()async{
  await seed();
  final encrypted=await exportV3();
  expect(encrypted.contains('My bank'),isFalse);
  final preview=await WaffraAccountsPortableBackupV3.verifyAndPreview(
   encryptedArchive:encrypted,password:password);
  expect(preview.accounts.length,2);
  expect(preview.links.length,1);
  expect(preview.transfers.length,1);
  final restored=WaffraEncryptedStore.openAt(
   File('${dir.path}/destination.sqlite'),key:'different-v3-test-key-longer-than-32-chars');
  try{
   await WaffraAccountsPortableBackupV3.restoreToEmptyEncryptedVault(
    encryptedArchive:encrypted,password:password,
    disposableStore:restored,userConfirmed:true,experimentalEnabled:true);
   final accounts=await WaffraAccountsRepository(
    db:restored,experimentalEnabled:true).balances();
   expect({for(final a in accounts)a.id:a.balanceMinor},
    {'bank':13000,'cash':2000});
   final entries=await restored.customSelect(
    'SELECT entry_id FROM fresh_finance_account_entry_links').get();
   expect(entries.single.read<String>('entry_id'),'salary');
  }finally{await restored.close();}
 });

 test('M440 V2 refuses account data while V3 accepts it',()async{
  await seed();
  final exporter=WaffraPortableEncryptedBackupExporter(
   snapshot:finance(db),
   receiptVault:WaffraEncryptedReceiptVault(
    store:db,experimentalEnabled:true),
   writerDirectory:dir,verifySourceUnderLock:()async{},
   experimentalEnabled:true);
  await expectLater(exporter.export(password:password),
   throwsA(isA<StateError>()));
  expect((await exporter.exportV3(password:password)).isNotEmpty,isTrue);
 });

 test('M440 authenticated V3 rejects forged account association',()async{
  await seed();
  final encrypted=await exportV3();
  final outer=jsonDecode(await WaffraSecureBackup.decrypt(encrypted,password))
   as Map<String,dynamic>;
  final links=(outer['links'] as List).cast<Map<String,dynamic>>();
  links.first['entry_id']='missing-ledger-entry';
  final forged=await WaffraSecureBackup.encrypt(jsonEncode(outer),password);
  await expectLater(
   WaffraAccountsPortableBackupV3.verifyAndPreview(
    encryptedArchive:forged,password:password),
   throwsA(isA<FormatException>()));
 });

 test('M440 wrong password blocks backup preview without creating destination',()async{
  await seed();
  final encrypted=await exportV3();
  await expectLater(WaffraAccountsPortableBackupV3.verifyAndPreview(
   encryptedArchive:encrypted,password:'incorrect-password'),
   throwsA(isA<Exception>()));
 });

 test('V3 preserves every finance history table and rejects orphan links atomically',() async {
  await seed();
  final fixture = <String, List<Object?>>{
    'fresh_finance_categories': ['cat','Food',null,0,0,'{}'],
    'fresh_finance_goals': ['goal','Rent',200000,3000,'{}'],
    'fresh_finance_recurring': ['monthly',5000,0,1,'{}'],
    'fresh_finance_standalone_budgets': ['budget','Home',30000,0,60,null,'2026-11-04','{}'],
    'fresh_finance_standalone_allocations': ['a','budget','salary',5000,'2026-11-04',1],
    'fresh_finance_named_budgets': ['named','Old budget','cat',20000,1,75,'2026-11-04','cat','{}'],
    'fresh_finance_budget_allocations': ['b','named','salary',3000,1,'2026-11-04'],
    'fresh_finance_goal_opening_balances': ['goal',3000,'0123456789abcdef','2026-11-04'],
    'fresh_finance_goal_wallet_movements': ['move','goal','due_debit',3000,'due-once','salary','2026-11-04'],
    'fresh_finance_goal_due_settlements': ['due','goal','monthly','salary',5000,3000,2000,'2026-11-04'],
    'fresh_finance_project_wallets': ['project','Kitchen',12000,0,'2026-11-04'],
    'fresh_finance_project_wallet_links': ['project','salary',1000],
    'fresh_finance_confirmed_subscriptions': ['sub','Service',1000,'SAR',1,'confirmed','2026-11-04','cat'],
    'fresh_finance_saved_scenarios': ['scenario','challenge','Savings','{}','2026-11-04'],
    'fresh_finance_ai_threads': ['thread','Plan',1,'2026-11-04'],
    'fresh_finance_ai_messages': ['message','thread','user','Plan','2026-11-04'],
    'fresh_finance_price_observations': ['quote','gold','SAR',12345,'test','2026-11-04'],
    'fresh_finance_notification_events': ['event','monthly','goal','2026-11-04','scheduled'],
  };
  for (final item in fixture.entries) {
    final marks = List.filled(item.value.length, '?').join(',');
    await db.customStatement('INSERT INTO ${item.key} VALUES ($marks)', item.value);
  }
  await db.customStatement("UPDATE fresh_finance_entries SET category_id='cat' WHERE entry_id='salary'");
  final archive = await exportV3();
  final target = WaffraEncryptedStore.openAt(
    File('${dir.path}/history.sqlite'), key: 'distinct-history-vault-key-at-least-32-bytes');
  try {
    final envelope = jsonDecode(await WaffraSecureBackup.decrypt(archive,password)) as Map;
    final history = envelope['financeHistoryV1'] as Map;
    (history['fresh_finance_goal_wallet_movements'] as List).single['goal_id'] = 'missing';
    final corrupt = await WaffraSecureBackup.encrypt(jsonEncode(envelope),password);
    Future<void> restore(String data) =>
      WaffraAccountsPortableBackupV3.restoreToEmptyEncryptedVault(
        encryptedArchive:data,password:password,disposableStore:target,
        userConfirmed:true,experimentalEnabled:true);
    await expectLater(restore(corrupt),throwsA(anything));
    await restore(archive); // The failed restore left the target reusable.
    final linked = await target.customSelect("SELECT category_id FROM fresh_finance_entries WHERE entry_id='salary'").getSingle();
    expect(linked.read<String>('category_id'),'cat');
    for (final table in fixture.keys) {
      final source = await db.customSelect('SELECT * FROM $table').getSingle();
      final restored = await target.customSelect('SELECT * FROM $table').getSingle();
      expect(restored.data,source.data,reason:table);
    }
    await expectLater(restore(archive),throwsA(anything));
    expect((await target.customSelect('SELECT * FROM fresh_finance_goal_wallet_movements').get()).length,1);
  } finally {
    await target.close();
  }
 });
}
