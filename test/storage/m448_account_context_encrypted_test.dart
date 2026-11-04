import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_account_context_read_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

void main(){
 late Directory dir;
 late WaffraEncryptedStore db;
 setUp(()async{
  dir=await Directory.systemTemp.createTemp('m448');
  db=WaffraEncryptedStore.openAt(File('${dir.path}/money.sqlite'),
   key:'m448-temporary-sqlcipher-test-key-only');
  await WaffraFreshEncryptedVaultBootstrap(store:db,experimentalEnabled:true)
   .initialize(decision:WaffraFirstRunDecision.freshCandidate);
  await WaffraAccountsSchema.install(db);
 });
 tearDown(()async{await db.close();await dir.delete(recursive:true);});
 test('independent budget counts bank and cash, alert uses total',()async{
  await db.customStatement(
   'INSERT INTO fresh_finance_standalone_budgets '
   '(budget_id,name,monthly_limit_minor,is_active,alert_percent,created_at_iso,source_json) '
   'VALUES (?,?,?,?,?,?,?)',
   ['food','Food',100000,1,30,'2026-11-01T00:00:00','{}']);
  for(final id in ['bank','cash']){
   await db.customStatement('INSERT INTO fresh_finance_money_accounts '
    '(account_id,label,kind,currency,opening_minor,created_iso) VALUES (?,?,?,?,?,?)',
    [id,id,id=='cash'?'cash':'bank','SAR',0,'2026-11-01T00:00:00']);
  }
  for(final id in ['bank','cash','unknown']){
   final minor=id=='bank'?20000:id=='cash'?10000:5000;
   await db.customStatement('INSERT INTO fresh_finance_entries '
    '(entry_id,title,category_snapshot,amount_minor,is_income,occurred_iso,receipt_count,source_json) '
    'VALUES (?,?,?,?,0,?,0,?)',[id,id,'Food',minor,'2026-11-04T12:00:00','{}']);
   if(id!='unknown'){
    await db.customStatement('INSERT INTO fresh_finance_account_entry_links '
     '(entry_id,account_id,confirmed_iso) VALUES (?,?,?)',
     [id,id,'2026-11-04T12:00:00']);
    await db.customStatement('INSERT INTO fresh_finance_standalone_allocations '
     '(allocation_id,budget_id,entry_id,amount_minor,assigned_at_iso,explicitly_confirmed) '
     'VALUES (?,?,?,?,?,1)',[id,'food',id,minor,'2026-11-04T12:00:00']);
   }
  }
  final view=WaffraAccountContextReadRepository(db:db,experimentalEnabled:true);
  final bank=await view.budget(budgetId:'food',month:DateTime(2026,11),accountId:'bank');
  final cash=await view.budget(budgetId:'food',month:DateTime(2026,11),accountId:'cash');
  expect(bank.selectedAccountSpentMinor,20000);
  expect(cash.selectedAccountSpentMinor,10000);
  expect(bank.allAccountsSpentMinor,30000);
  expect(bank.alertReached,isTrue);
  expect((await view.withoutAccount()).single.id,'unknown');
 });
}
