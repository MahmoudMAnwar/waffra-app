import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_account_context_read.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_sqlcipher_history_pager.dart';

/// Each finance entry may have only one standalone budget allocation.
/// Verify source-level UNIQUE(entry_id), separate budget totals and stable
/// SQLCipher history/keyset pagination without duplicate money.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('M952 UNIQUE budget links preserve one bank debit per entry '
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
          ('rent-entry',2000,'2026-11-04T12:00:00'),
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
          ('r-rent','rent','rent-entry',2000),
          ('f-unassigned','food','unassigned',1500)
        ]) {
          await db!.customStatement(
            'INSERT INTO fresh_finance_standalone_allocations '
            '(allocation_id,budget_id,entry_id,amount_minor,assigned_at_iso,'
            'explicitly_confirmed) VALUES (?,?,?,?,?,1)',
            [id,budget,entry,minor,stamp]);
        }
      });
      // A second allocation for the SAME entry must fail closed at the
      // encrypted schema boundary, not silently double-count money.
      await expectLater(db.customStatement(
        'INSERT INTO fresh_finance_standalone_allocations '
        '(allocation_id,budget_id,entry_id,amount_minor,assigned_at_iso,'
        'explicitly_confirmed) VALUES (?,?,?,?,?,1)',
        ['duplicate','rent','shared',8000,stamp]),throwsA(isA<Exception>()));
      await accounts.linkEntry(entryId:'shared',accountId:'bank',
        linkedIso:stamp,userConfirmed:true);
      final balancesBefore={
        for(final row in await accounts.balances())row.id:row.balanceMinor
      };
      expect(balancesBefore['bank'],92000);
      final month=await WaffraAccountContextRead.load(store:db,
        monthIso:'2026-11',selectedAccountId:'bank',summaryOnly:true);
      expect(month.entries.map((e)=>e.id).toSet(),
        {'shared','rent-entry','unassigned'});
      expect(month.entries.length,3,
        reason:'One posted expense cannot produce two ledger cards.');
      final shared=month.entries.singleWhere((e)=>e.id=='shared');
      expect(shared.budgetId,'food',
        reason:'The source permits only one budget per entry.');
      final budgets={for(final b in month.budgets)b.id:b.usage};
      expect(budgets['food']!.globalSpentMinor,9500);
      expect(budgets['food']!.selectedAccountSpentMinor,8000);
      expect(budgets['rent']!.globalSpentMinor,2000);
      expect(budgets['rent']!.selectedAccountSpentMinor,0);
      final historical=await WaffraAccountContextRead.load(
        store:db,monthIso:'2026-11',summaryOnly:false);
      expect(historical.entries.length,4);
      expect(historical.entries.map((e)=>e.id).toSet(),
        {'shared','rent-entry','unassigned','october'});
      final bounded=await WaffraAccountContextRead.loadMonthEntries(
        store:db,monthIso:'2026-11',limit:20);
      expect(bounded.map((e)=>e.id).toSet(),
        {'shared','rent-entry','unassigned'});
      expect(bounded.length,3);

      final page1=await WaffraSqlcipherHistoryPager.load(
        store:db,limit:1,monthIso:'2026-11');
      expect(page1.entries.single.id,'unassigned');
      expect(page1.hasMore,isTrue);
      final page2=await WaffraSqlcipherHistoryPager.load(
        store:db,limit:1,monthIso:'2026-11',after:page1.nextCursor);
      expect(page2.entries.single.id,'shared');
      expect(page2.hasMore,isTrue);
      final page3=await WaffraSqlcipherHistoryPager.load(
        store:db,limit:1,monthIso:'2026-11',after:page2.nextCursor);
      expect(page3.entries.single.id,'rent-entry');
      expect(page3.hasMore,isFalse);
      expect(page3.nextCursor,isNull);
      expect({
        for(final row in await accounts.balances())row.id:row.balanceMinor
      },balancesBefore,reason:'All projections are read-only.');
      expect((await db.customSelect(
        'SELECT COUNT(*) AS n FROM fresh_finance_entries')
        .getSingle()).read<int>('n'),4);
      expect((await db.customSelect(
        'SELECT COUNT(*) AS n FROM fresh_finance_standalone_allocations')
        .getSingle()).read<int>('n'),3);
    } finally {
      await db?.close();
      if(await dir.exists())await dir.delete(recursive:true);
    }
  });
}
