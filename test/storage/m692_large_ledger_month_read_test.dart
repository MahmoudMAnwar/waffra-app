import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_account_context_read.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

/// M692 / #636: real disposable SQLCipher query under 2,400 synthetic entries.
/// Record an elapsed duration, but never interpret it as physical Android speed.
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 test('M692 month SQL read scales and pages without historical/balance drift',()async{
  final dir=await Directory.systemTemp.createTemp('m692-ledger-');
  final path=File('${dir.path}/vault.sqlite');
  const key='m692-disposable-sqlcipher-only';
  WaffraEncryptedStore? db;
  try{
   db=WaffraEncryptedStore.openAt(path,key:key);
   await WaffraFreshEncryptedVaultBootstrap(
    store:db,experimentalEnabled:true).initialize(
    decision:WaffraFirstRunDecision.freshCandidate);
   await WaffraAccountsSchema.install(db);
   await WaffraAccountsRepository(db:db,experimentalEnabled:true).createAccount(
    id:'bank',name:'Synthetic Bank',kind:'bank',openingMinor:100000,
    createdIso:'2026-11-01T00:00:00',userConfirmed:true);
   const sql='INSERT INTO fresh_finance_entries '
    '(entry_id,title,category_snapshot,amount_minor,is_income,'
    'occurred_iso,receipt_count,source_json) VALUES (?,?,?,?,?,?,0,?)';
   await db.transaction(()async{
    for(var i=0;i<2400;i++){
     final id='synthetic-${i.toString().padLeft(5,'0')}';
     final occurred=i.isEven?'2026-11-04T12:00:00':'2026-10-04T12:00:00';
     await db!.customStatement(sql,[id,id,'Food',125,i%17==0?1:0,
      occurred,'{}']);
    }
   });
   final sw=Stopwatch()..start();
   final november=await WaffraAccountContextRead.load(
    store:db,monthIso:'2026-11',summaryOnly:true);
   final first=await WaffraAccountContextRead.loadMonthEntries(
    store:db,monthIso:'2026-11',limit:80,offset:0);
   final second=await WaffraAccountContextRead.loadMonthEntries(
    store:db,monthIso:'2026-11',limit:80,offset:80);
   final october=await WaffraAccountContextRead.loadMonthEntries(
    store:db,monthIso:'2026-10',limit:100);
   sw.stop();
   // Diagnostic only: this is a runner's encrypted-database elapsed time,
   // not a benchmark of the user's Android phone.
   // ignore: avoid_print
   print('M692 disposable SQLCipher 2400 rows, month+3 pages: '
    '${sw.elapsedMilliseconds} ms');
   expect(sw.elapsed,lessThan(const Duration(seconds:45)));
   expect(november.entries.length,1200);
   expect(first.length,80);
   expect(second.length,80);
   expect(first.map((e)=>e.id).toSet().intersection(
    second.map((e)=>e.id).toSet()),isEmpty);
   expect(first.every((e)=>e.occurredIso.startsWith('2026-11')),true);
   expect(october.every((e)=>e.occurredIso.startsWith('2026-10')),true);
   final all=await WaffraAccountContextRead.load(
    store:db,monthIso:'2026-11',summaryOnly:false);
   expect(all.entries.length,2400);
   expect(all.entries.map((e)=>e.id).toSet().length,2400);
   expect((await WaffraAccountsRepository(
    db:db,experimentalEnabled:true).balances()).single.balanceMinor,100000);
   await db.close();
   db=null;
   db=WaffraEncryptedStore.openAt(path,key:key);
   final reopened=await WaffraAccountContextRead.loadMonthEntries(
    store:db,monthIso:'2026-11',limit:80);
   expect(reopened.map((e)=>e.id).toList(),
    first.map((e)=>e.id).toList());
  }finally{
   await db?.close();
   if(await dir.exists())await dir.delete(recursive:true);
  }
 });
}
