import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_account_context_read.dart';
import 'package:waffra/storage/waffra_account_context_schema.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

/// M950: SQL-backed cross-month, account/budget/legacy-read user journeys.
/// Disposable SQLCipher database; never uses an owner backup or live device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late WaffraEncryptedStore db;
  const key='m950-synthetic-account-month-history-test-key';
  const approvedAt='2026-11-15T12:00:00';
  WaffraAccountsRepository accounts()=>WaffraAccountsRepository(
    db:db,experimentalEnabled:true);
  Future<void> make(String id,{int opening=0})=>accounts().createAccount(
    id:id,name:id,kind:'bank',openingMinor:opening,
    createdIso:approvedAt,userConfirmed:true);
  Future<void> add(String id,int minor,String occurred,
    {bool income=false,String? account})async{
    await db.customStatement('INSERT INTO fresh_finance_entries '
      '(entry_id,title,category_snapshot,amount_minor,is_income,'
      'occurred_iso,receipt_count,source_json) VALUES (?,?,?,?,?,?,0,?)',[
      id,'Finance '+id,'General',minor,income?1:0,occurred,'{}']);
    if(account!=null)await accounts().linkEntry(
      entryId:id,accountId:account,linkedIso:approvedAt,userConfirmed:true);
  }
  Future<void> budget(String id,int limit)async{
    await db.customStatement('INSERT INTO fresh_finance_standalone_budgets '
      '(budget_id,name,monthly_limit_minor,created_at_iso,source_json) '
      'VALUES (?,?,?,?,?)',[id,id,limit,approvedAt,'{}']);
  }
  Future<void> allocation(String id,String budgetId,String entryId,
    int minor)async{
    await db.customStatement('INSERT INTO fresh_finance_standalone_allocations '
      '(allocation_id,budget_id,entry_id,amount_minor,assigned_at_iso,'
      'explicitly_confirmed) VALUES (?,?,?,?,?,1)',
      [id,budgetId,entryId,minor,approvedAt]);
  }
  Future<List<String>> month(String ym,{String? account,int limit=100,
    int offset=0})async=>(await WaffraAccountContextRead.loadMonthEntries(
      store:db,monthIso:ym,selectedAccountId:account,
      limit:limit,offset:offset)).map((r)=>r.id).toList();
  Future<int> links()async=>(await db.customSelect(
    'SELECT count(*) AS n FROM fresh_finance_account_entry_links')
    .getSingle()).read<int>('n');
  Future<Map<String,int>> balances()async=>{
    for(final a in await accounts().balances())a.id:a.balanceMinor};
  Future<int> attach(String id,String account,{
    bool confirmed=true,bool openingExcludesHistory=false})=>
    WaffraAccountContextRead.attachPreviouslyUnassigned(
      store:db,entryId:id,accountId:account,confirmedIso:approvedAt,
      userConfirmed:confirmed,openingExcludesHistory:openingExcludesHistory);

  setUp(()async{
    directory=await Directory.systemTemp.createTemp('m950-month-vault-');
    db=WaffraEncryptedStore.openAt(
      File('${directory.path}/finance.sqlite'),key:key);
    await WaffraFreshEncryptedVaultBootstrap(store:db,experimentalEnabled:true)
      .initialize(decision:WaffraFirstRunDecision.freshCandidate);
    await WaffraAccountsSchema.install(db);
    // The monthly read projection joins goal source links, even with zero goals.
    // Install the actual account-context schema, not a mock or skipped join.
    await WaffraAccountContextSchema.install(db);
  });
  tearDown(()async{
    await db.close();
    if(await directory.exists())await directory.delete(recursive:true);
  });

  test('M950-S01 December-to-January month boundary does not lose or mix verified bank rows',()async{
    await make('bank');
    await add('dec',100,'2026-12-31T23:59:59',account:'bank');
    await add('jan',200,'2027-01-01T00:00:00',account:'bank');
    expect(await month('2026-12',account:'bank'),['dec']);
    expect(await month('2027-01',account:'bank'),['jan']);
    expect(await balances(),{'bank':-300});
  });
  test('M950-S02 summaryOnly across leap February retains exact 29th and excludes March',()async{
    await add('leap',333,'2028-02-29T23:59:59');
    await add('march',400,'2028-03-01T00:00:00');
    final feb=await WaffraAccountContextRead.load(
      store:db,monthIso:'2028-02',summaryOnly:true);
    expect(feb.entries.map((e)=>e.id).toList(),['leap']);
    expect(await month('2028-03'),['march']);
  });
  test('M950-S03 identical event times page deterministically by descending entry ID',()async{
    for(final id in ['a','c','b','z']){
      await add(id,100,'2026-11-10T12:00:00');
    }
    expect(await month('2026-11',limit:2),['z','c']);
    expect(await month('2026-11',limit:2,offset:2),['b','a']);
  });
  test('M950-S04 selected bank page excludes other bank and unassigned matching month',()async{
    await make('bank');await make('wallet');
    await add('bank-row',100,'2026-11-15T10:00:00',account:'bank');
    await add('wallet-row',200,'2026-11-15T11:00:00',account:'wallet');
    await add('orphan',300,'2026-11-15T12:00:00');
    expect(await month('2026-11',account:'bank'),['bank-row']);
    expect(await month('2026-11',account:'wallet'),['wallet-row']);
    expect(await month('2026-11'),['orphan','wallet-row','bank-row']);
  });
  test('M950-S05 unknown selected account has empty page without inferring an owner',()async{
    await make('bank');
    await add('bank-row',123,'2026-11-15T10:00:00',account:'bank');
    expect(await month('2026-11',account:'unknown'),isEmpty);
    expect(await month('2026-11',account:'bank'),['bank-row']);
    expect(await links(),1);
  });
  test('M950-S06 unassigned summary nets positive incomes and negative expenses across years',()async{
    await add('pay',2000,'2025-12-31T23:59:59',income:true);
    await add('expense1',600,'2026-01-01T00:00:00');
    await add('expense2',400,'2027-11-01T08:00:00');
    final snapshot=await WaffraAccountContextRead.unassignedSummary(store:db);
    expect(snapshot.count,3);
    expect(snapshot.netMinor,1000);
    expect(await links(),0);
  });
  test('M950-S07 unassigned 13-item review pages never skip tie timestamps',()async{
    for(var i=0;i<13;i++){
      await add('id-${i.toString().padLeft(2,'0')}',100,
        '2026-11-15T11:00:00');
    }
    final seen=<String>[];
    for(var offset=0;offset<13;offset+=5){
      final page=await WaffraAccountContextRead.loadUnassignedEntries(
        store:db,limit:5,offset:offset);
      seen.addAll(page.map((r)=>r.id));
    }
    expect(seen.length,13);
    expect(seen.toSet().length,13);
    expect(seen.first,'id-12');
    expect(seen.last,'id-00');
  });
  test('M950-S08 explicit zero-opening association updates selected month and unassigned net',()async{
    await make('bank');
    await add('orphan-in',1000,'2026-11-11T12:00:00',income:true);
    await add('orphan-out',250,'2026-11-12T12:00:00');
    expect((await WaffraAccountContextRead.unassignedSummary(
      store:db)).netMinor,750);
    expect(await attach('orphan-in','bank'),1);
    expect(await month('2026-11',account:'bank'),['orphan-in']);
    final after=await WaffraAccountContextRead.unassignedSummary(store:db);
    expect(after.count,1);
    expect(after.netMinor,-250);
    expect(await balances(),{'bank':1000});
  });
  test('M950-S09 two legacy cash movements reattach once and survive encrypted cold reopen',()async{
    await make('bank');
    await add('legacy-income',1000,'2026-09-09T13:00:00',income:true);
    await add('legacy-expense',750,'2026-09-10T13:00:00');
    expect(await attach('legacy-income','bank'),1);
    expect(await attach('legacy-expense','bank'),1);
    expect(await attach('legacy-income','bank'),1);
    expect(await links(),2);
    expect(await balances(),{'bank':250});
    await db.close();
    db=WaffraEncryptedStore.openAt(
      File('${directory.path}/finance.sqlite'),key:key);
    expect(await month('2026-09',account:'bank'),
      ['legacy-expense','legacy-income']);
    expect(await links(),2);
    expect(await balances(),{'bank':250});
    expect((await WaffraAccountContextRead.unassignedSummary(
      store:db)).count,0);
  });
  test('M950-S10 failed reassignment after original bank link cannot steal transaction',()async{
    await make('bank');await make('wallet');
    await add('one',120,'2026-11-12T12:00:00');
    await attach('one','bank');
    await expectLater(attach('one','wallet'),throwsStateError);
    expect(await month('2026-11',account:'bank'),['one']);
    expect(await month('2026-11',account:'wallet'),isEmpty);
    expect(await links(),1);
  });
  test('M950-S11 rejected historical confirmation leaves review queue and bank untouched',()async{
    await make('bank');
    await add('orphan',650,'2026-11-12T12:00:00');
    await expectLater(attach('orphan','bank',confirmed:false),throwsStateError);
    expect((await WaffraAccountContextRead.unassignedSummary(
      store:db)).count,1);
    expect(await links(),0);
    expect(await balances(),{'bank':0});
  });
  test('M950-S12 invalid year-month spellings cannot query historical bank data',()async{
    for(final invalid in ['2026-00','2026-13','2026-1','2026-11-extra']){
      await expectLater(WaffraAccountContextRead.loadMonthEntries(
        store:db,monthIso:invalid),throwsArgumentError);
    }
  });
  test('M950-S13 invalid month paging limits and offsets are rejected before SQL',()async{
    for(final (limit,offset) in [(0,0),(501,0),(100,-1),(-1,0)]){
      await expectLater(WaffraAccountContextRead.loadMonthEntries(
        store:db,monthIso:'2026-11',limit:limit,offset:offset),
        throwsArgumentError);
    }
  });
  test('M950-S14 month-specific budget spending separates cross-year and unassigned rows',()async{
    await make('bank');await make('wallet');await budget('food',1000);
    await add('nov-bank',400,'2026-11-15T12:00:00',account:'bank');
    await add('nov-wallet',300,'2026-11-16T12:00:00',account:'wallet');
    await add('nov-orphan',100,'2026-11-17T12:00:00');
    await add('dec-bank',900,'2026-12-01T12:00:00',account:'bank');
    await allocation('a','food','nov-bank',400);
    await allocation('b','food','nov-wallet',300);
    await allocation('c','food','nov-orphan',100);
    await allocation('d','food','dec-bank',900);
    final nov=await WaffraAccountContextRead.load(
      store:db,monthIso:'2026-11',selectedAccountId:'bank');
    final dec=await WaffraAccountContextRead.load(
      store:db,monthIso:'2026-12',selectedAccountId:'bank');
    expect(nov.budgets.single.usage.globalSpentMinor,800);
    expect(nov.budgets.single.usage.selectedAccountSpentMinor,400);
    expect(nov.budgets.single.usage.reached(80),true);
    expect(dec.budgets.single.usage.globalSpentMinor,900);
    expect(dec.budgets.single.usage.selectedAccountSpentMinor,900);
    expect(dec.budgets.single.usage.reached(90),true);
    expect(await links(),3);
  });
  test('M950-S15 switching account header changes budget share but not stored finance',()async{
    await make('bank');await make('wallet');await budget('rent',2000);
    await add('bank-expense',501,'2026-11-16T12:00:00',account:'bank');
    await add('wallet-expense',700,'2026-11-16T12:01:00',account:'wallet');
    await allocation('bank-a','rent','bank-expense',501);
    await allocation('wallet-a','rent','wallet-expense',700);
    final before=await balances();
    final a=await WaffraAccountContextRead.load(
      store:db,monthIso:'2026-11',selectedAccountId:'bank');
    final b=await WaffraAccountContextRead.load(
      store:db,monthIso:'2026-11',selectedAccountId:'wallet');
    expect(a.budgets.single.usage.globalSpentMinor,1201);
    expect(b.budgets.single.usage.globalSpentMinor,1201);
    expect(a.budgets.single.usage.selectedAccountSpentMinor,501);
    expect(b.budgets.single.usage.selectedAccountSpentMinor,700);
    expect(await balances(),before);
    expect(await links(),2);
  });
  test('M950-S16 real internal account transfer cannot appear in income expense ID filter',()async{
    await make('bank',opening:1000);await make('wallet');
    await accounts().transfer(id:'transfer-1',fromAccountId:'bank',
      toAccountId:'wallet',amountMinor:200,occurredIso:approvedAt,
      userConfirmed:true);
    await add('invoice',50,'2026-11-15T11:00:00',account:'bank');
    expect(await WaffraAccountContextRead.loadAccountEntryIds(
      store:db,accountId:'bank'),{'invoice'});
    expect(await WaffraAccountContextRead.loadAccountEntryIds(
      store:db,accountId:'wallet'),isEmpty);
    expect(await balances(),{'bank':750,'wallet':200});
  });
  test('M950-S17 archived account cannot take newly linked historical salary',()async{
    await make('old');
    await accounts().archiveEmptyAccount(id:'old',userConfirmed:true);
    await add('late-salary',500,'2026-11-15T11:00:00',income:true);
    await expectLater(attach('late-salary','old'),throwsStateError);
    expect(await links(),0);
    expect((await WaffraAccountContextRead.unassignedSummary(
      store:db)).netMinor,500);
  });
  test('M950-S18 monthly query result cannot be mutated to fake persisted account association',()async{
    await add('raw-history',100,'2026-11-15T11:00:00');
    final rows=await WaffraAccountContextRead.loadMonthEntries(
      store:db,monthIso:'2026-11');
    expect(()=>rows.clear(),throwsUnsupportedError);
    expect(rows.single.accountId,null);
    expect(await links(),0);
    expect((await WaffraAccountContextRead.unassignedSummary(
      store:db)).count,1);
  });
}
