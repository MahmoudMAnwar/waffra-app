import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_account_context_read.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_sqlcipher_history_pager.dart';

/// Two confirmed standalone allocations may refer to ONE old expense.
 /// The ledger and the account balance must count that expense only once,
 /// while each independent budget retains its actual saved allocation.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('M952 budget fan-out preserves one bank debit and every allocation '
      'across SQLCipher keyset, monthly and full-history reads', () async {
    final dir=await Directory.systemTemp.createTemp('m952-multibudget-');
    WaffraEncryptedStore? db;
    try {
      db=WaffraEncryptedStore.openAt(File('${dir.path}/vault.sqlite'),
        key:'m952-multibudget-disposable-vault-key');
      await WaffraFreshEncryptedVaultBootstrap(store:db,
        experimentalEnabled:true).initialize(
          decision:WaffraFirstRunDecision.freshCandidate);
      await WaffraAccountsSchema.install(db);
      final accounts=WaffraAccountsRepository(db:db,experimentalEnabled:true);
      const stamp='2026-11-05T12:00:00';
      await accounts.createAccount(id:'bank',name:'Bank',kind:'bank',
        openingMinor:100000,createdIso:stamp,userConfirmed:true);
      await db.transaction(()async {
        for(final (id,amount,date) in <(String,int,String)>[
          ('shared',8000,stamp),
          ('unassigned',1500,'2026-11-06T12:00:00'),
          ('october',500,'2026-10-07T12:00:00')
        ]) {
          await db!.customStatement(
            'INSERT INTO fresh_finance_entries '
            '(entry_id,title,category_snapshot,amount_minor,is_income,'
            'occurred_iso,receipt_count,source_json) VALUES (?,?,?,?,?,?,0,?)',
            [id,id,'Food',amount,0,date,'{}']);
        }
        for(final id in const ['food','rent']) {
          await db!.customStatement(
            'INSERT INTO fresh_finance_standalone_budgets '
            '(budget_id,name,monthly_limit_minor,created_at_iso,source_json) '
            'VALUES (?,?,?,?,?)',[id,id,20000,stamp,'{}']);
        }
        for(final (id,budget,entry,minor) in <(String,String,String,int)>[
          ('f-shared','food','shared',8000),
          ('r-shared','rent','shared',8000),
          ('f-unassigned','food','unassigned',1500)
        ]) {
          await db!.customStatement(
            'INSERT INTO fresh_finance_standalone_allocations '
            '(allocation_id,budget_id,entry_id,amount_minor,assigned_at_iso,'
            'explicitly_confirmed) VALUES (?,?,?,?,?,1)',
            [id,budget,entry,minor,stamp]);
        }
      });
      await accounts.linkEntry(entryId:'shared',accountId:'bank',
        linkedIso:stamp,userConfirmed:true);
      final balancesBefore={
        for(final row in await accounts.balances())row.id:row.balanceMinor
      };
      expect(balancesBefore['bank'],92000);
      final month=await WaffraAccountContextRead.load(store:db,
        monthIso:'2026-11',selectedAccountId:'bank',summaryOnly:true);
      expect(month.entries.map((e)=>e.id).toSet(),
        {'shared','unassigned'});
      expect(month.entries.length,2,
        reason:'One posted expense cannot produce two ledger cards.');
      final shared=month.entries.singleWhere((e)=>e.id=='shared');
      expect(shared.budgetId,isNull,
        reason:'Two budgets must not be guessed as one linked budget.');
      final budgets={for(final b in month.budgets)b.id:b.usage};
      expect(budgets['food']!.globalSpentMinor,9500);
      expect(budgets['food']!.selectedAccountSpentMinor,8000);
      expect(budgets['rent']!.globalSpentMinor,8000);
      expect(budgets['rent']!.selectedAccountSpentMinor,8000);
      final historical=await WaffraAccountContextRead.load(
        store:db,monthIso:'2026-11',summaryOnly:false);
      expect(historical.entries.length,3);
      expect(historical.entries.map((e)=>e.id).toSet(),
        {'shared','unassigned','october'});
      final bounded=await WaffraAccountContextRead.loadMonthEntries(
        store:db,monthIso:'2026-11',limit:20);
      expect(bounded.map((e)=>e.id).toSet(),{'shared','unassigned'});
      expect(bounded.length,2);

      final page1=await WaffraSqlcipherHistoryPager.load(
        store:db,limit:1,monthIso:'2026-11');
      expect(page1.entries.single.id,'unassigned');
      expect(page1.hasMore,isTrue);
      final page2=await WaffraSqlcipherHistoryPager.load(
        store:db,limit:1,monthIso:'2026-11',after:page1.nextCursor);
      expect(page2.entries.single.id,'shared');
      expect(page2.hasMore,isFalse);
      expect(page2.nextCursor,isNull);
      expect({
        for(final row in await accounts.balances())row.id:row.balanceMinor
      },balancesBefore,reason:'All projections are read-only.');
      expect((await db.customSelect(
        'SELECT COUNT(*) AS n FROM fresh_finance_entries')
        .getSingle()).read<int>('n'),3);
      expect((await db.customSelect(
        'SELECT COUNT(*) AS n FROM fresh_finance_standalone_allocations')
        .getSingle()).read<int>('n'),3);
    } finally {
      await db?.close();
      if(await dir.exists())await dir.delete(recursive:true);
    }
  });
}
