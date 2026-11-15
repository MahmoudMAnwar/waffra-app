import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

/// M960 axes 1/2/3/5: compare the optimized SQLCipher account balances
/// against the exact original correlated subquery arithmetic over mixed
/// finance sources. Never uses or mutates a user backup.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('M960 bank/wallet/archived and 360 entries keep exact halala parity '
      'through transfers, goal movements, partial due and cold reopen', () async {
    final dir=await Directory.systemTemp.createTemp('m960-account-balance-');
    final file=File('${dir.path}/finance.sqlite');
    const key='m960-disposable-grouped-balance-parity-key';
    WaffraEncryptedStore? db;
    try {
      db=WaffraEncryptedStore.openAt(file,key:key);
      final seeded=db;
      await WaffraFreshEncryptedVaultBootstrap(
        store:seeded,experimentalEnabled:true,
      ).initialize(decision:WaffraFirstRunDecision.freshCandidate);
      await WaffraAccountsSchema.install(seeded);
      final accounts=WaffraAccountsRepository(
        db:seeded,experimentalEnabled:true);
      const stamp='2026-11-15T09:00:00';
      for(final (id,opening) in <(String,int)>[
        ('bank-a',500000),('bank-b',400000),
        ('wallet',200000),('archived',0)
      ]){
        await accounts.createAccount(
          id:id,name:id,kind:id=='wallet'?'wallet':'bank',
          openingMinor:opening,createdIso:stamp,userConfirmed:true);
      }
      await seeded.customStatement(
        "UPDATE fresh_finance_money_accounts SET archived=1 "
        "WHERE account_id='archived'");
      await seeded.transaction(()async{
        for(var i=0;i<360;i++){
          final id='tx-$i';
          final income=i%7==0;
          final amount=103+i%49;
          await seeded.customStatement(
            'INSERT INTO fresh_finance_entries '
            '(entry_id,title,category_snapshot,amount_minor,is_income,'
            'occurred_iso,receipt_count,source_json) VALUES (?,?,?,?,?,?,0,?)',
            [id,id,'Test',amount,income?1:0,stamp,'{}']);
          if(i%8!=0) {
            await seeded.customStatement(
              'INSERT INTO fresh_finance_account_entry_links '
              '(entry_id,account_id,confirmed_iso) VALUES (?,?,?)',
              [id,i%3==0?'bank-a':i%3==1?'bank-b':'wallet',stamp]);
          }
        }
        await seeded.customStatement(
          'INSERT INTO fresh_finance_goals '
          '(goal_id,name,target_minor,saved_minor,source_json) '
          'VALUES (?,?,?,?,?)',
          ['home-goal','Home',200000,75000,'{}']);
        await seeded.customStatement(
          'INSERT INTO fresh_finance_recurring '
          '(recurring_id,amount_minor,is_income,due_day,source_json) '
          'VALUES (?,?,?,?,?)',['rent',20000,0,15,'{}']);
        await seeded.customStatement(
          'INSERT INTO fresh_finance_entries '
          '(entry_id,title,category_snapshot,amount_minor,is_income,'
          'occurred_iso,receipt_count,source_json) VALUES (?,?,?,?,?,?,0,?)',
          ['rent-2026','Rent','Rent',20000,0,stamp,'{}']);
        await seeded.customStatement(
          'INSERT INTO fresh_finance_goal_due_settlements '
          '(due_key,goal_id,recurring_id,entry_id,amount_minor,'
          'goal_wallet_minor,current_cash_minor,confirmed_at_iso) '
          'VALUES (?,?,?,?,?,?,?,?)',
          ['rent-due','home-goal','rent','rent-2026',
            20000,17000,3000,stamp]);
        await seeded.customStatement(
          'INSERT INTO fresh_finance_account_entry_links '
          '(entry_id,account_id,confirmed_iso) VALUES (?,?,?)',
          ['rent-2026','bank-a',stamp]);
        for(final (id,kind,amount,bank) in
            <(String,String,int,String)>[
              ('save-one','fund',12000,'bank-a'),
              ('release-one','release',2000,'bank-a'),
              ('save-two','fund',4000,'bank-b')
            ]){
          await seeded.customStatement(
            'INSERT INTO fresh_finance_goal_wallet_movements '
            '(movement_id,goal_id,kind,amount_minor,idempotency_key,'
            'occurred_at_iso) VALUES (?,?,?,?,?,?)',
            [id,'home-goal',kind,amount,id,stamp]);
          await seeded.customStatement(
            'INSERT INTO fresh_finance_goal_account_sources '
            '(movement_id,account_id,linked_iso) VALUES (?,?,?)',
            [id,bank,stamp]);
        }
      });
      final beforeTransfer=await accounts.balances();
      final sumBefore=beforeTransfer.fold<int>(
        0,(sum,a)=>sum+a.balanceMinor);
      for(var i=0;i<12;i++){
        final from=i.isEven?'bank-a':'wallet';
        final to=i.isEven?'bank-b':'bank-a';
        expect(await accounts.transfer(
          id:'transfer-$i',fromAccountId:from,toAccountId:to,
          amountMinor:1100+i,occurredIso:stamp,userConfirmed:true),true);
      }
      final expected=await seeded.customSelect('''
SELECT a.account_id,a.opening_minor+
 COALESCE((SELECT SUM(CASE WHEN e.is_income=1 THEN e.amount_minor
   WHEN due.entry_id IS NOT NULL THEN -due.current_cash_minor
   ELSE -e.amount_minor END)
  FROM fresh_finance_account_entry_links l
  JOIN fresh_finance_entries e ON e.entry_id=l.entry_id
  LEFT JOIN fresh_finance_goal_due_settlements due ON due.entry_id=e.entry_id
  WHERE l.account_id=a.account_id),0)+
 COALESCE((SELECT SUM(t.amount_minor)
  FROM fresh_finance_internal_transfers t
  WHERE t.to_account_id=a.account_id),0)-
 COALESCE((SELECT SUM(t.amount_minor)
  FROM fresh_finance_internal_transfers t
  WHERE t.from_account_id=a.account_id),0)+
 COALESCE((SELECT SUM(CASE WHEN m.kind='fund' THEN -m.amount_minor
   WHEN m.kind='release' THEN m.amount_minor ELSE 0 END)
  FROM fresh_finance_goal_account_sources s
  JOIN fresh_finance_goal_wallet_movements m ON m.movement_id=s.movement_id
  WHERE s.account_id=a.account_id),0) AS balance_minor
FROM fresh_finance_money_accounts a
ORDER BY a.created_iso,a.account_id
''').get();
      final oldBalances={for(final row in expected)
        row.read<String>('account_id'):row.read<int>('balance_minor')};
      final newAccounts=await accounts.balances();
      final newBalances={for(final a in newAccounts)a.id:a.balanceMinor};
      expect(newBalances,oldBalances);
      expect(newAccounts.map((a)=>a.id).toList(),
        ['archived','bank-a','bank-b','wallet']);
      expect(newAccounts.singleWhere((a)=>a.id=='archived').archived,true);
      expect(newAccounts.fold<int>(0,(sum,a)=>sum+a.balanceMinor),
        sumBefore,reason:'All internal transfers conserve total money.');
      expect((await seeded.customSelect(
        "SELECT COUNT(*) AS n FROM fresh_finance_entries")
        .getSingle()).read<int>('n'),361);
      expect((await seeded.customSelect(
        "SELECT COUNT(*) AS n FROM fresh_finance_internal_transfers")
        .getSingle()).read<int>('n'),12);
      await seeded.close();
      db=WaffraEncryptedStore.openAt(file,key:key);
      final reopened=WaffraAccountsRepository(
        db:db,experimentalEnabled:true);
      expect({for(final a in await reopened.balances())
        a.id:a.balanceMinor},oldBalances);
    } finally {
      await db?.close();
      if(await dir.exists())await dir.delete(recursive:true);
    }
  });
}
