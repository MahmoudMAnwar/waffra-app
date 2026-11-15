import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_account_context_read.dart';
import 'package:waffra/storage/waffra_account_context_repository.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

/// Actual disposable SQLCipher source, never a mocked Home summary.
/// The new selected-account header must not deserialize the same transaction
/// cards Home already owns, but cannot alter a single halala or goal source.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('M955 900-row verified Home summary equals monthly budgets/goals '
      'without loading ledger cards or writing account money', () async {
    final dir=await Directory.systemTemp.createTemp('m955-home-summary-');
    WaffraEncryptedStore? db;
    try {
      db=WaffraEncryptedStore.openAt(File('${dir.path}/finance.sqlite'),
        key:'m955-isolated-encrypted-performance-fixture');
      await WaffraFreshEncryptedVaultBootstrap(store:db,
        experimentalEnabled:true).initialize(
          decision:WaffraFirstRunDecision.freshCandidate);
      await WaffraAccountsSchema.install(db);
      final accounts=WaffraAccountsRepository(db:db,experimentalEnabled:true);
      const stamp='2026-11-01T12:00:00';
      await accounts.createAccount(id:'bank',name:'Bank',kind:'bank',
        openingMinor:5000000,createdIso:stamp,userConfirmed:true);
      await accounts.createAccount(id:'wallet',name:'Wallet',kind:'wallet',
        openingMinor:3000000,createdIso:stamp,userConfirmed:true);

      await db.transaction(() async {
        for (final (id,limit) in <(String,int)>[
          ('food',300000),('commute',400000)
        ]) {
          await db!.customStatement(
            'INSERT INTO fresh_finance_standalone_budgets '
            '(budget_id,name,monthly_limit_minor,created_at_iso,source_json) '
            'VALUES (?,?,?,?,?)',[id,id,limit,stamp,'{}']);
        }
        for(var i=0;i<900;i++){
          final id='expense-$i';
          final month=i<870?'11':'10';
          final day=(1+i%27).toString().padLeft(2,'0');
          final iso='2026-$month-${day}T12:00:00';
          final minor=75+i%111;
          final income=i%13==0;
          await db!.customStatement(
            'INSERT INTO fresh_finance_entries '
            '(entry_id,title,category_snapshot,amount_minor,is_income,'
            'occurred_iso,receipt_count,source_json) VALUES (?,?,?,?,?,?,0,?)',
            [id,id,'Expense',minor,income?1:0,iso,'{}']);
          if(i%3!=2){
            await db!.customStatement(
              'INSERT INTO fresh_finance_account_entry_links '
              '(entry_id,account_id,confirmed_iso) VALUES (?,?,?)',
              [id,i%3==0?'bank':'wallet',stamp]);
          }
          if(i%4<2){
            await db!.customStatement(
              'INSERT INTO fresh_finance_standalone_allocations '
              '(allocation_id,budget_id,entry_id,amount_minor,assigned_at_iso,'
              'explicitly_confirmed) VALUES (?,?,?,?,?,1)',
              ['alloc-$i',i%4==0?'food':'commute',id,minor,stamp]);
          }
        }
      });

      await db.customStatement('INSERT INTO fresh_finance_goals '
        '(goal_id,name,target_minor,saved_minor,source_json) '
        'VALUES (?,?,?,?,?)',['travel','Travel',90000,24000,'{}']);
      await db.customStatement(
        'INSERT INTO fresh_finance_goal_wallet_movements '
        '(movement_id,goal_id,kind,amount_minor,idempotency_key,occurred_at_iso) '
        'VALUES (?,?,?,?,?,?)',
        ['fund-one','travel','fund',12000,'m955-fund-once',stamp]);
      final attribution=WaffraAccountContextRepository(
        store:db,experimentalEnabled:true);
      expect(await attribution.attributeGoalMovement(
        movementId:'fund-one',accountId:'bank',
        linkedIso:stamp,userConfirmed:true),true);

      final before={
        for(final row in await accounts.balances())row.id:row.balanceMinor
      };
      final sourceRows=(await db.customSelect(
        'SELECT COUNT(*) AS n FROM fresh_finance_entries')
        .getSingle()).read<int>('n');
      expect(sourceRows,900);
      for(final id in <String?>['bank','wallet',null]){
        final regular=await WaffraAccountContextRead.load(
          store:db,monthIso:'2026-11',selectedAccountId:id,
          summaryOnly:true);
        final compact=await WaffraAccountContextRead.load(
          store:db,monthIso:'2026-11',selectedAccountId:id,
          summaryOnly:true,includeEntries:false);
        expect(regular.entries.length,870);
        expect(compact.entries,isEmpty,
          reason:'Only the Home header skips monthly ledger hydration.');
        final regularBudgets={for(final b in regular.budgets)b.id:b};
        final compactBudgets={for(final b in compact.budgets)b.id:b};
        expect(compactBudgets.keys.toSet(),regularBudgets.keys.toSet());
        for(final key in regularBudgets.keys){
          final old=regularBudgets[key]!.usage;
          final current=compactBudgets[key]!.usage;
          expect(current.globalSpentMinor,old.globalSpentMinor);
          expect(current.selectedAccountSpentMinor,
            old.selectedAccountSpentMinor);
          expect(current.limitMinor,old.limitMinor);
        }
        final goals={for(final g in regular.goals)g.id:g};
        final lightGoals={for(final g in compact.goals)g.id:g};
        expect(lightGoals.keys.toSet(),goals.keys.toSet());
        for(final key in goals.keys){
          expect(lightGoals[key]!.totalSavedMinor,
            goals[key]!.totalSavedMinor);
          expect(lightGoals[key]!.selectedAccountNetMinor,
            goals[key]!.selectedAccountNetMinor);
        }
      }
      expect((await WaffraAccountContextRead.load(
        store:db,monthIso:'2026-11',selectedAccountId:'bank',
        summaryOnly:true,includeEntries:false))
          .goals.single.selectedAccountNetMinor,12000);
      expect((await WaffraAccountContextRead.load(
        store:db,monthIso:'2026-11',selectedAccountId:'wallet',
        summaryOnly:true,includeEntries:false))
          .goals.single.selectedAccountNetMinor,0);
      expect(await WaffraAccountContextRead.loadAccountEntryIds(
        store:db,accountId:'bank'),hasLength(300),
        reason:'All-time linked IDs remain available for historic filters.');
      await expectLater(WaffraAccountContextRead.load(
        store:db,monthIso:'2026-11',includeEntries:false),
        throwsA(isA<ArgumentError>()));
      expect({
        for(final row in await accounts.balances())row.id:row.balanceMinor
      },before,reason:'Both encrypted projections must be read-only.');
      expect((await db.customSelect(
        'SELECT COUNT(*) AS n FROM fresh_finance_entries')
        .getSingle()).read<int>('n'),sourceRows);
    } finally {
      await db?.close();
      if(await dir.exists())await dir.delete(recursive:true);
    }
  });
}
