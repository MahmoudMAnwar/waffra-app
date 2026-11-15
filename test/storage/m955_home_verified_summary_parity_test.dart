import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart' show defaultCategories;
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_cutover_journal.dart';
import 'package:waffra/storage/waffra_encrypted_finance_session.dart';
import 'package:waffra/storage/waffra_fresh_home_catalog_recovery.dart';
import 'package:waffra/storage/waffra_fresh_install_source.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_verified_accounts_api.dart';
import 'package:waffra/storage/waffra_verified_encrypted_finance_bridge.dart';
import 'package:waffra/storage/waffra_verified_finance_authority.dart';

import 'package:waffra/storage/waffra_account_context_read.dart';
import 'package:waffra/storage/waffra_account_context_repository.dart';
import 'package:waffra/storage/waffra_account_context_schema.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

/// Actual disposable SQLCipher source, never a mocked Home summary.
/// The new selected-account header must not deserialize the same transaction
/// cards Home already owns, but cannot alter a single halala or goal source.
class _M956ActiveEncryptedSource extends WaffraProductionFinanceSourceGuard {
 @override
 Future<WaffraProductionFinanceSourceReport> inspect({
  SharedPreferences? preferences,
 }) async => const WaffraProductionFinanceSourceReport(
  source:WaffraProductionFinanceSource.encryptedRoutingRequired,
  reasonCode:'m956-single-witness-encrypted-account-fixture',
 );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('M956 real activated SQLCipher Home view agrees with verified '
       'separate account reads and never rewrites finance', () async {
    SharedPreferences.setMockInitialValues({});
    final directory=await Directory.systemTemp.createTemp('m956-home-owner-');
    WaffraEncryptedStore? db;
    try {
      String? key;
      final fresh=await WaffraFreshInstallSource.prepareIn(
        directory,readKey:()async=>key,writeKey:(value)async{key=value;});
      expect(fresh,isNotNull);
      db=WaffraEncryptedStore.openAt(
        File('${directory.path}/${WaffraEncryptedStore.encryptedDatabaseFilename}'),
        key:key!);
      final snapshot=WaffraAtomicFinanceSnapshot(
        store:db,experimentalEnabled:true);
      final bridge=WaffraVerifiedEncryptedFinanceBridge(
        snapshot:snapshot,
        cutoverJournal:WaffraEncryptedCutoverJournal(
          store:db,snapshot:snapshot,experimentalEnabled:true),
        writerDirectory:directory,allWritersRoutedVerified:true,
        secureKeyVerified:true,experimentalEnabled:true);
      final authority=WaffraVerifiedFinanceAuthority(
        sourceGuard:_M956ActiveEncryptedSource(),freshInstall:fresh,
        encryptedSession:WaffraEncryptedFinanceSession(
          bridge:bridge,experimentalEnabled:true),
        encryptedSqlWitnessActive:true,externalSourceWitnessActive:true,
        verifiedKeyRecoveryInDevice:true);
      await WaffraFreshHomeCatalogRecovery.load(
        authority:authority,defaultCategoriesJson:jsonEncode(
          defaultCategories().map((c)=>c.toJson()).toList()));
      final api=WaffraVerifiedAccountsApi(bridge:bridge);
      await api.balances();
      await api.createAccount(
        id:'bank',name:'Verified Riyadh Bank',kind:'bank',
        openingMinor:235050,createdIso:'2026-11-15T11:00:00Z',
        userConfirmed:true);
      final before=await snapshot.read();
      final selected=await api.readHomeAccountView(
        monthIso:'2026-11',selectedAccountId:'bank');
      expect(selected.selectedAccountId,'bank');
      expect(selected.balances.singleWhere((a)=>a.id=='bank').balanceMinor,
        235050);
      expect(selected.context,isNotNull);
      expect(selected.context!.entries,isEmpty);
      expect(selected.entryIds,isEmpty);
      final ordinaryBalances=await api.balances();
      final ordinaryContext=await api.readAccountContext(
        monthIso:'2026-11',selectedAccountId:'bank',
        summaryOnly:true,includeEntries:false);
      final ordinaryIds=await api.readAccountEntryIds(accountId:'bank');
      expect(ordinaryBalances.single.balanceMinor,
        selected.balances.single.balanceMinor);
      expect(ordinaryContext.budgets.length,selected.context!.budgets.length);
      expect(ordinaryContext.goals.length,selected.context!.goals.length);
      expect(ordinaryIds,selected.entryIds);
      final stale=await api.readHomeAccountView(
        monthIso:'2026-11',selectedAccountId:'missing-or-archived');
      expect(stale.selectedAccountId,'all');
      expect(stale.context,isNull);
      expect(stale.entryIds,isNull);
      expect(stale.balances.single.balanceMinor,235050);
      final all=await api.readHomeAccountView(
        monthIso:'2026-11',selectedAccountId:'all');
      expect(all.selectedAccountId,'all');
      expect(all.context,isNull);
      expect(all.entryIds,isNull);
      final after=await snapshot.read();
      expect(after.generation,before.generation);
      expect(after.digest,before.digest);
      expect((await WaffraAccountsRepository(
        db:db,experimentalEnabled:true).balances()).single.balanceMinor,
        235050,reason:'Home financial reads must never post money.');
    } finally {
      await db?.close();
      if(await directory.exists())await directory.delete(recursive:true);
    }
  });

  test('M956 Home bank selection is a single authenticated source read', () {
    final bridge=File(
      'lib/storage/waffra_verified_encrypted_finance_bridge.dart')
        .readAsStringSync();
    final start=bridge.indexOf('readVerifiedHomeAccountView({');
    final end=bridge.indexOf(
      '/// Read account balances with a source witness',start);
    expect(start,greaterThan(0));
    expect(end,greaterThan(start));
    final guarded=bridge.substring(start,end);
    expect('withExclusiveAccess(() async {'.allMatches(
      guarded).length,1);
    expect(guarded,contains('await _requireActivatedUnderLock();'));
    expect(guarded,contains('final before = await snapshot.read();'));
    expect(guarded,contains('final after = await snapshot.read();'));
    expect(guarded,contains('before.digest != after.digest'));
    expect(guarded,contains('before.generation != after.generation'));
    expect(guarded,contains('!a.archived && a.id == selectedAccountId'));
    expect(guarded,contains('includeEntries: false'));
    expect(guarded,contains('WaffraAccountContextRead.loadAccountEntryIds('));
    final api=File('lib/storage/waffra_verified_accounts_api.dart')
      .readAsStringSync();
    expect(api,contains('readHomeAccountView({'));
    expect(api,contains('bridge.readVerifiedHomeAccountView('));
    final home=File('lib/waffra_home_verified_account_flows.part.dart')
      .readAsStringSync();
    final begin=home.indexOf('Future<void> _m468ReadVerifiedAccountsOnce()');
    final last=home.indexOf('String get _m467AccountLabel',begin);
    expect(begin,greaterThan(0));
    expect(last,greaterThan(begin));
    final read=home.substring(begin,last);
    expect(read,contains('await api.readHomeAccountView('));
    expect(read,isNot(contains('await api.balances();')));
    expect(read,isNot(contains('await api.readAccountContext(')));
    expect(read,isNot(contains('await api.readAccountEntryIds(')));
    expect(read,contains('chosen=verified.selectedAccountId;'));
    expect(read,contains('readEpoch!=_m627AccountEpoch'));
    expect(read,contains('final requested=chosen;'));
    expect(read,contains('_m467SelectedAccount!=requested'));
    expect(read,isNot(contains('_m467SelectedAccount!=chosen')));
  });

  test('M955 900-row verified Home summary equals monthly budgets/goals '
      'without loading ledger cards or writing account money', () async {
    final home=File('lib/waffra_home_verified_account_flows.part.dart')
      .readAsStringSync();
    expect(home,contains('await api.readHomeAccountView('));
    expect(home,contains('chosen=verified.selectedAccountId;'));
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
          ('food',300000),('commute',400000),
          ('unused',1000),('archived',5000)
        ]) {
          await db!.customStatement(
            'INSERT INTO fresh_finance_standalone_budgets '
            '(budget_id,name,monthly_limit_minor,created_at_iso,source_json) '
            'VALUES (?,?,?,?,?)',[id,id,limit,stamp,'{}']);
        }
        await db!.customStatement(
          "UPDATE fresh_finance_standalone_budgets SET archived_at_iso=? "
          "WHERE budget_id='archived'",[stamp]);
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
          if(i%4<3){
            await db!.customStatement(
              'INSERT INTO fresh_finance_standalone_allocations '
              '(allocation_id,budget_id,entry_id,amount_minor,assigned_at_iso,'
              'explicitly_confirmed) VALUES (?,?,?,?,?,1)',
              ['alloc-$i',i%4==0?'food':i%4==1?'commute':'archived',
                id,minor,stamp]);
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
        expect(compactBudgets.keys.toSet(),
          {'food','commute','unused'},
          reason:'Archived budgets are not silently revived by SQL aggregation.');
        expect(compactBudgets['unused']!.usage.globalSpentMinor,0);
        expect(compactBudgets['unused']!.usage.selectedAccountSpentMinor,0);
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
      for(final invalid in const ['2026-00','2026-13','2026-1','2026-99']){
        await expectLater(WaffraAccountContextRead.load(
          store:db,monthIso:invalid,summaryOnly:true,
          includeEntries:false),throwsA(isA<ArgumentError>()));
        await expectLater(WaffraAccountContextRead.load(
          store:db,monthIso:invalid,summaryOnly:true),
          throwsA(isA<ArgumentError>()));
      }
      expect({
        for(final row in await accounts.balances())row.id:row.balanceMinor
      },before,reason:'Both encrypted projections must be read-only.');
      expect((await db.customSelect(
        'SELECT COUNT(*) AS n FROM fresh_finance_entries')
        .getSingle()).read<int>('n'),sourceRows);
      // Real SQLCipher close/reopen: no in-memory cache may be required for
      // selected-account header source parity or historical membership.
      final warmBank=await WaffraAccountContextRead.load(
        store:db,monthIso:'2026-11',selectedAccountId:'bank',
        summaryOnly:true,includeEntries:false);
      final warmBudgets={for(final b in warmBank.budgets)
        b.id:(b.usage.globalSpentMinor,b.usage.selectedAccountSpentMinor)};
      await db.close();
      db=WaffraEncryptedStore.openAt(File('${dir.path}/finance.sqlite'),
        key:'m955-isolated-encrypted-performance-fixture');
      final coldBank=await WaffraAccountContextRead.load(
        store:db,monthIso:'2026-11',selectedAccountId:'bank',
        summaryOnly:true,includeEntries:false);
      expect(coldBank.entries,isEmpty);
      expect({for(final b in coldBank.budgets)
        b.id:(b.usage.globalSpentMinor,b.usage.selectedAccountSpentMinor)},
        warmBudgets);
      expect(coldBank.goals.single.totalSavedMinor,24000);
      expect(coldBank.goals.single.selectedAccountNetMinor,12000);
      final reopenedAccounts=WaffraAccountsRepository(
        db:db,experimentalEnabled:true);
      expect({for(final row in await reopenedAccounts.balances())
        row.id:row.balanceMinor},before);
      expect(await WaffraAccountContextRead.loadAccountEntryIds(
        store:db,accountId:'bank'),hasLength(300));
    } finally {
      await db?.close();
      if(await dir.exists())await dir.delete(recursive:true);
    }
  });

  test('M955 accountless legacy finance summary preserves unassigned money '
      'without creating bank accounts or duplicate cards', () async {
    // Model the restored accountless domain: old entries and wallets exist,
    // but the owner has not explicitly created/linked any money account.
    final dir=await Directory.systemTemp.createTemp('m955-accountless-');
    WaffraEncryptedStore? db;
    try {
      db=WaffraEncryptedStore.openAt(File('${dir.path}/accountless.sqlite'),
        key:'m955-disposable-accountless-legacy-source');
      await WaffraFreshEncryptedVaultBootstrap(store:db,
        experimentalEnabled:true).initialize(
          decision:WaffraFirstRunDecision.freshCandidate);
      await WaffraAccountsSchema.install(db);
      // Old V3 accountless restores still install the empty versioned account
      // attribution schema. Its absence is corrupted data, never a zero bank.
      await WaffraAccountContextSchema.install(db);
      const stamp='2026-11-04T10:00:00';
      for(final (id,amount,income) in <(String,int,bool)>[
        ('legacy-expense',7000,false),
        ('legacy-income',9500,true),
      ]){
        await db.customStatement(
          'INSERT INTO fresh_finance_entries '
          '(entry_id,title,category_snapshot,amount_minor,is_income,'
          'occurred_iso,receipt_count,source_json) VALUES (?,?,?,?,?,?,0,?)',
          [id,id,'Legacy',amount,income?1:0,stamp,'{}']);
      }
      await db.customStatement(
        'INSERT INTO fresh_finance_standalone_budgets '
        '(budget_id,name,monthly_limit_minor,created_at_iso,source_json) '
        'VALUES (?,?,?,?,?)',['legacy-budget','Legacy',12000,stamp,'{}']);
      await db.customStatement(
        'INSERT INTO fresh_finance_standalone_allocations '
        '(allocation_id,budget_id,entry_id,amount_minor,assigned_at_iso,'
        'explicitly_confirmed) VALUES (?,?,?,?,?,1)',
        ['legacy-budget-link','legacy-budget','legacy-expense',7000,stamp]);
      await db.customStatement(
        'INSERT INTO fresh_finance_goals '
        '(goal_id,name,target_minor,saved_minor,source_json) '
        'VALUES (?,?,?,?,?)',['old-goal','Old goal',30000,15000,'{}']);
      final legacy=await WaffraAccountContextRead.load(
        store:db,monthIso:'2026-11',summaryOnly:true);
      final compact=await WaffraAccountContextRead.load(
        store:db,monthIso:'2026-11',summaryOnly:true,
        includeEntries:false);
      expect(legacy.entries.map((e)=>e.id).toSet(),
        {'legacy-expense','legacy-income'});
      expect(compact.entries,isEmpty);
      expect(compact.budgets.single.usage.globalSpentMinor,7000);
      expect(compact.budgets.single.usage.selectedAccountSpentMinor,0);
      expect(legacy.budgets.single.usage.globalSpentMinor,
        compact.budgets.single.usage.globalSpentMinor);
      expect(compact.goals.single.totalSavedMinor,15000);
      expect(compact.goals.single.selectedAccountNetMinor,0);
      expect(await WaffraAccountsRepository(db:db,
        experimentalEnabled:true).balances(),isEmpty,
        reason:'Never guess a bank opening balance from legacy net flow.');
      await db.close();
      db=WaffraEncryptedStore.openAt(File('${dir.path}/accountless.sqlite'),
        key:'m955-disposable-accountless-legacy-source');
      final reopened=await WaffraAccountContextRead.load(
        store:db,monthIso:'2026-11',summaryOnly:true,
        includeEntries:false);
      expect(reopened.entries,isEmpty);
      expect(reopened.budgets.single.usage.globalSpentMinor,7000);
      expect(reopened.goals.single.totalSavedMinor,15000);
      expect(await WaffraAccountsRepository(db:db,
        experimentalEnabled:true).balances(),isEmpty);
      expect((await db.customSelect(
        'SELECT COUNT(*) AS n FROM fresh_finance_entries')
        .getSingle()).read<int>('n'),2);
    }finally{
      await db?.close();
      if(await dir.exists())await dir.delete(recursive:true);
    }
  });

}
