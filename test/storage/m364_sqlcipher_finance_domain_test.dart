import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_fresh_finance_domain_schema.dart';
import 'package:waffra/storage/waffra_fresh_finance_domain_repository.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_verified_goal_due_snapshot_writer.dart';

void main() {
  late Directory directory;
  late WaffraEncryptedStore db;
  const secret = 'm364-disposable-only-sqlcipher-key-123456789';

  WaffraFreshFinanceDomainRepository repo({bool enabled = true}) =>
      WaffraFreshFinanceDomainRepository(
        store: db, experimentalEnabled: enabled,
      );

  Future<int> count(String table) async {
    final row = await db.customSelect(
      'SELECT count(*) AS n FROM $table',
    ).getSingle();
    return row.read<int>('n');
  }

  Future<void> addCategory(String id, {String parent = '',bool income=false}) =>
      db.customStatement(
        'INSERT INTO fresh_finance_categories '
        '(category_id,name,parent_id,is_income,budget_minor,source_json) '
        'VALUES (?,?,?,?,0,?)',
        [id,id,parent,income ? 1 : 0,jsonEncode({
          'id':id,'name':id,'parentId':parent,'income':income,'budget':0,
        })],
      );

  Future<void> addEntry(String id, String categoryId,
      {int amountMinor=7500,bool income=false}) =>
      db.customStatement(
        'INSERT INTO fresh_finance_entries '
        '(entry_id,title,category_id,category_snapshot,amount_minor,is_income,'
        'occurred_iso,receipt_count,source_json) VALUES (?,?,?,?,?,?,?,0,?)',
        [id,id,categoryId,categoryId,amountMinor,income ? 1 : 0,
         '2026-11-01T12:00:00',jsonEncode({
          'id':id,'title':id,'category':categoryId,'income':income,
          'date':'2026-11-01T12:00:00','amount':amountMinor/100,
        })],
      );

  Future<void> addGoal({String id='goal',int savedMinor=15000}) =>
      db.customStatement(
        'INSERT INTO fresh_finance_goals '
        '(goal_id,name,target_minor,saved_minor,source_json) VALUES (?,?,?,?,?)',
        [id,id,30000,savedMinor,jsonEncode({
          'id':id,'name':'هدف الادخار','target':300.0,
          'saved':savedMinor/100,'dueDate':'2026-11-01T00:00:00',
        })],
      );

  Future<void> addRecurring({String id='rent',String goalId='goal',
      int amountMinor=20000}) =>
      db.customStatement(
        'INSERT INTO fresh_finance_recurring '
        '(recurring_id,amount_minor,is_income,due_day,source_json) '
        'VALUES (?,?,0,1,?)',
        [id,amountMinor,jsonEncode({
          'id':id,'title':'سداد الهدف','category':'سكن / إيجار',
          'amount':amountMinor/100,'income':false,'day':1,'active':true,
          'startAt':'2026-11-01T00:00:00','linkedGoalId':goalId,
        })],
      );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('waffra-m364-');
    db = WaffraEncryptedStore.openAt(
      File('${directory.path}/m364.sqlite'), key: secret,
    );
  });

  tearDown(() async {
    await db.close();
    if (await directory.exists()) await directory.delete(recursive:true);
  });

  Future<void> bootstrap() async {
    await WaffraFreshEncryptedVaultBootstrap(
      store:db,experimentalEnabled:true,
    ).initialize(decision:WaffraFirstRunDecision.freshCandidate);
  }

  test('M364 empty SQLCipher creates all 13 domain tables without fake data',
      () async {
    await bootstrap();
    for (final table in WaffraFreshFinanceDomainSchema.domainTables) {
      expect(await count(table),0,reason:table);
    }
    expect(await count('fresh_finance_domain_revision'),1);
    await bootstrap();
    expect(await count('fresh_finance_domain_revision'),1);
    await db.close();
    db = WaffraEncryptedStore.openAt(
      File('${directory.path}/m364.sqlite'),key:secret,
    );
    await WaffraFreshFinanceDomainSchema.requireReady(db);
    expect(await count('fresh_finance_named_budgets'),0);
  });

  test('M365 missing SQLCipher domain table never silently resets stored data',
      () async {
    await bootstrap();
    await db.customStatement(
      'DROP TABLE fresh_finance_saved_scenarios',
    );
    await expectLater(WaffraFreshFinanceDomainSchema.requireReady(db),
      throwsA(isA<StateError>()));
    await expectLater(bootstrap(),throwsA(isA<StateError>()));
    final stillMissing=await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='fresh_finance_saved_scenarios'",
    ).get();
    expect(stillMissing,isEmpty,
      reason:'Versioned schema must not recreate an empty replacement table');
  });

  test('M364 refuses unapproved writers and refuses absent schema',() async {
    await expectLater(repo().createNamedBudget(
      budgetId:'x',name:'Car',categoryId:'fuel',limitMinor:100,
      createdAtIso:'2026-11-01T12:00:00',
    ),throwsA(isA<StateError>()));
    await bootstrap();
    await expectLater(repo(enabled:false).createNamedBudget(
      budgetId:'x',name:'Car',categoryId:'fuel',limitMinor:100,
      createdAtIso:'2026-11-01T12:00:00',
    ),throwsA(isA<StateError>()));
  });

  test('M364 many budgets per subcategory; paused budgets do not auto-link',
      () async {
    await bootstrap();
    await addCategory('car');
    await addCategory('fuel',parent:'car');
    await addEntry('pos-1','fuel');
    await repo().createNamedBudget(
      budgetId:'fuel-2026',name:'وقود',categoryId:'fuel',
      limitMinor:30000,createdAtIso:'2026-11-01T12:00:00',
    );
    await repo().createNamedBudget(
      budgetId:'fuel-trip',name:'بنزين الرحلات',categoryId:'fuel',
      limitMinor:20000,createdAtIso:'2026-11-01T12:00:00',
    );
    expect(await count('fresh_finance_named_budgets'),2);
    await repo().setBudgetActive('fuel-2026',false);
    await expectLater(repo().assignExpenseToBudget(
      allocationId:'a1',entryId:'pos-1',budgetId:'fuel-2026',
      allocatedMinor:7500,assignedAtIso:'2026-11-01T13:00:00',
      userConfirmed:true,
    ),throwsA(isA<StateError>()));
    expect(await count('fresh_finance_budget_allocations'),0);
    await repo().setBudgetActive('fuel-2026',true);
    // Re-enable doesn't attach the previous transaction automatically.
    expect(await count('fresh_finance_budget_allocations'),0);
    await repo().assignExpenseToBudget(
      allocationId:'a1',entryId:'pos-1',budgetId:'fuel-2026',
      allocatedMinor:3000,assignedAtIso:'2026-11-01T13:00:00',
      userConfirmed:true,
    );
    await repo().assignExpenseToBudget(
      allocationId:'a2',entryId:'pos-1',budgetId:'fuel-trip',
      allocatedMinor:4500,assignedAtIso:'2026-11-01T13:00:00',
      userConfirmed:true,
    );
    expect(await count('fresh_finance_budget_allocations'),2);
    await expectLater(repo().assignExpenseToBudget(
      allocationId:'a3',entryId:'pos-1',budgetId:'fuel-trip',
      allocatedMinor:1,assignedAtIso:'2026-11-01T13:00:00',
      userConfirmed:true,
    ),throwsA(isA<StateError>()));
    expect(await count('fresh_finance_budget_allocations'),2);
  });

  test('M365 edit, pause, delete and reassign budgets preserve prior money',
      () async {
    await bootstrap();
    await addCategory('car');
    await addCategory('fuel',parent:'car');
    await addEntry('expense-1','fuel');
    expect(await repo().listUnassignedExpenseIds(),['expense-1']);
    for (final id in ['old','new']) {
      await repo().createNamedBudget(
        budgetId:id,name:id,categoryId:'fuel',limitMinor:10000,
        createdAtIso:'2026-11-01T12:00:00',
      );
    }
    await repo().editNamedBudget(
      budgetId:'old',name:'ميزانية الوقود',limitMinor:20000,
      alertPercent:75,userConfirmed:true,
    );
    final edited=await db.customSelect(
      "SELECT name,monthly_limit_minor,alert_percent FROM "
      "fresh_finance_named_budgets WHERE budget_id='old'",
    ).getSingle();
    expect(edited.read<String>('name'),'ميزانية الوقود');
    expect(edited.read<int>('monthly_limit_minor'),20000);
    expect(edited.read<int>('alert_percent'),75);
    await repo().assignExpenseToBudget(
      allocationId:'allocation-1',entryId:'expense-1',budgetId:'old',
      allocatedMinor:7500,assignedAtIso:'2026-11-01T13:00:00',
      userConfirmed:true,
    );
    expect(await repo().listUnassignedExpenseIds(),isEmpty);
    await repo().setBudgetActive('new',false);
    await expectLater(repo().replaceExpenseBudget(
      allocationId:'allocation-1',newBudgetId:'new',allocatedMinor:7500,
      assignedAtIso:'2026-11-01T14:00:00',userConfirmed:true,
    ),throwsA(isA<StateError>()));
    final original=await db.customSelect(
      "SELECT budget_id FROM fresh_finance_budget_allocations "
      "WHERE allocation_id='allocation-1'",
    ).getSingle();
    expect(original.read<String>('budget_id'),'old',
      reason:'A failed reassignment must roll back its original allocation');
    await repo().setBudgetActive('new',true);
    await repo().replaceExpenseBudget(
      allocationId:'allocation-1',newBudgetId:'new',allocatedMinor:7500,
      assignedAtIso:'2026-11-01T15:00:00',userConfirmed:true,
    );
    final changed=await db.customSelect(
      "SELECT budget_id FROM fresh_finance_budget_allocations "
      "WHERE allocation_id='allocation-1'",
    ).getSingle();
    expect(changed.read<String>('budget_id'),'new');
    await repo().deleteNamedBudget(
      budgetId:'new',deletedAtIso:'2026-11-01T16:00:00',
      userConfirmed:true,
    );
    await expectLater(repo().setBudgetActive('new',true),
      throwsA(isA<StateError>()));
    expect(await count('fresh_finance_budget_allocations'),1,
      reason:'Soft deletion must preserve old allocations for audit');
    await repo().unassignExpenseBudget(
      allocationId:'allocation-1',userConfirmed:true);
    expect(await repo().listUnassignedExpenseIds(),['expense-1']);
    expect((await db.customSelect(
      "SELECT amount_minor FROM fresh_finance_entries "
      "WHERE entry_id='expense-1'",
    ).getSingle()).read<int>('amount_minor'),7500);
  });

  test('M364 category FK, expense-only and user consent are enforced',
      () async {
    await bootstrap();
    await addCategory('root');
    await addCategory('income',income:true);
    await expectLater(repo().createNamedBudget(
      budgetId:'bad-root',name:'bad',categoryId:'root',limitMinor:100,
      createdAtIso:'2026-11-01T12:00:00',
    ),throwsA(isA<StateError>()));
    await expectLater(repo().createNamedBudget(
      budgetId:'bad-income',name:'bad',categoryId:'income',limitMinor:100,
      createdAtIso:'2026-11-01T12:00:00',
    ),throwsA(isA<StateError>()));
    await addCategory('child',parent:'root');
    await repo().createNamedBudget(
      budgetId:'ok',name:'Budget',categoryId:'child',limitMinor:10000,
      createdAtIso:'2026-11-01T12:00:00',
    );
    await addEntry('income-entry','income',income:true);
    await expectLater(repo().assignExpenseToBudget(
      allocationId:'x',entryId:'income-entry',budgetId:'ok',
      allocatedMinor:100,assignedAtIso:'2026-11-01T13:00:00',
      userConfirmed:true,
    ),throwsA(isA<StateError>()));
    await addEntry('expense-1','child');
    await expectLater(repo().assignExpenseToBudget(
      allocationId:'x',entryId:'expense-1',budgetId:'ok',
      allocatedMinor:100,assignedAtIso:'2026-11-01T13:00:00',
      userConfirmed:false,
    ),throwsA(isA<StateError>()));
    expect(await count('fresh_finance_budget_allocations'),0);
  });

  test('M364 opening balance is witnessed, not fabricated history',() async {
    await bootstrap();
    await addGoal();
    await expectLater(repo().attestGoalOpening(
      goalId:'goal',savedMinor:1,sourceDigest:'12345678901234567890',
      witnessedAtIso:'2026-11-01T12:00:00',
    ),throwsA(isA<StateError>()));
    await repo().attestGoalOpening(
      goalId:'goal',savedMinor:15000,sourceDigest:'12345678901234567890',
      witnessedAtIso:'2026-11-01T12:00:00',
    );
    expect(await count('fresh_finance_goal_opening_balances'),1);
    expect(await count('fresh_finance_goal_wallet_movements'),0);
  });

  test('M364 fund may exceed cash, replays once, releases at most saved',
      () async {
    await bootstrap();
    await addGoal(savedMinor:0);
    expect(await repo().updateGoalSavings(
      movementId:'fund-1',goalId:'goal',amountMinor:50000,
      release:false,idempotencyKey:'user-funded-1',
      occurredAtIso:'2026-11-01T13:00:00',userConfirmed:true,
    ),isTrue);
    expect(await repo().updateGoalSavings(
      movementId:'fund-1',goalId:'goal',amountMinor:50000,
      release:false,idempotencyKey:'user-funded-1',
      occurredAtIso:'2026-11-01T13:00:00',userConfirmed:true,
    ),isFalse);
    final balance=await db.customSelect(
      "SELECT saved_minor FROM fresh_finance_goals WHERE goal_id='goal'",
    ).getSingle();
    expect(balance.read<int>('saved_minor'),50000);
    expect(await count('fresh_finance_goal_wallet_movements'),1);
    await expectLater(repo().updateGoalSavings(
      movementId:'release-bad',goalId:'goal',amountMinor:50001,
      release:true,idempotencyKey:'release-bad',
      occurredAtIso:'2026-11-01T14:00:00',userConfirmed:true,
    ),throwsA(isA<StateError>()));
    expect(await count('fresh_finance_goal_wallet_movements'),1);
    expect(await repo().updateGoalSavings(
      movementId:'release-1',goalId:'goal',amountMinor:5000,
      release:true,idempotencyKey:'release-1',
      occurredAtIso:'2026-11-01T14:00:00',userConfirmed:true,
    ),isTrue);
    expect(await count('fresh_finance_goal_wallet_movements'),2);
  });

  test('M364 goal due atomic split and one-time id after reopen',() async {
    await bootstrap();
    await addGoal();
    await addRecurring();
    final receipt=await repo().settleLinkedGoalDue(
      goalId:'goal',recurringId:'rent',dueKey:'rec_rent_2026_11',
      amountMinor:20000,confirmedAtIso:'2026-11-02T12:00:00',
      userConfirmed:true,
    );
    expect(receipt.alreadySettled,false);
    expect(receipt.fromGoalMinor,15000);
    expect(receipt.fromCurrentMinor,5000);
    expect(await count('fresh_finance_entries'),1);
    expect(await count('fresh_finance_goal_due_settlements'),1);
    expect(await count('fresh_finance_goal_wallet_movements'),1);
    final saved=await db.customSelect(
      "SELECT saved_minor,source_json FROM fresh_finance_goals WHERE goal_id='goal'",
    ).getSingle();
    expect(saved.read<int>('saved_minor'),0);
    expect((jsonDecode(saved.read<String>('source_json')) as Map)['saved'],0.0);
    final recurring=await db.customSelect(
      "SELECT source_json FROM fresh_finance_recurring WHERE recurring_id='rent'",
    ).getSingle();
    expect((jsonDecode(recurring.read<String>('source_json')) as Map)['active'],false);
    await db.close();
    db=WaffraEncryptedStore.openAt(
      File('${directory.path}/m364.sqlite'),key:secret,
    );
    final repeat=await repo().settleLinkedGoalDue(
      goalId:'goal',recurringId:'rent',dueKey:'rec_rent_2026_11',
      amountMinor:20000,confirmedAtIso:'2026-11-02T13:00:00',
      userConfirmed:true,
    );
    expect(repeat.alreadySettled,true);
    expect(await count('fresh_finance_entries'),1);
    expect(await count('fresh_finance_goal_wallet_movements'),1);
  });

  test('M364 rejected due never writes partial money or disables plan',
      () async {
    await bootstrap();
    await addGoal();
    await addRecurring();
    await expectLater(repo().settleLinkedGoalDue(
      goalId:'goal',recurringId:'rent',dueKey:'rec_rent_2026_12',
      amountMinor:20000,confirmedAtIso:'2026-11-02T12:00:00',
      userConfirmed:true,
    ),throwsA(isA<StateError>()));
    await expectLater(repo().settleLinkedGoalDue(
      goalId:'goal',recurringId:'rent',dueKey:'rec_rent_2026_11',
      amountMinor:20000,confirmedAtIso:'2026-11-02T12:00:00',
      userConfirmed:false,
    ),throwsA(isA<StateError>()));
    expect(await count('fresh_finance_entries'),0);
    expect(await count('fresh_finance_goal_due_settlements'),0);
    expect(await count('fresh_finance_goal_wallet_movements'),0);
    final saved=await db.customSelect(
      "SELECT saved_minor FROM fresh_finance_goals WHERE goal_id='goal'",
    ).getSingle();
    expect(saved.read<int>('saved_minor'),15000);
  });
  test('M365 atomic goal due updates typed SQL and Home/Widget snapshot once',
      () async {
    await bootstrap();
    await addGoal();
    await addRecurring();
    final snapshot=WaffraAtomicFinanceSnapshot(
      store:db,experimentalEnabled:true);
    await snapshot.initializeEmpty();
    final goalSource=await db.customSelect(
      "SELECT source_json FROM fresh_finance_goals WHERE goal_id='goal'",
    ).getSingle();
    final scheduleSource=await db.customSelect(
      "SELECT source_json FROM fresh_finance_recurring WHERE recurring_id='rent'",
    ).getSingle();
    await snapshot.commit(
      expectedGeneration:0,fullFinanceSnapshot:{
        'entries':'[]',
        'waffra_goals_v24':jsonEncode([
          jsonDecode(goalSource.read<String>('source_json')),
        ]),
        'waffra_recurring_v24':jsonEncode([
          jsonDecode(scheduleSource.read<String>('source_json')),
        ]),
      },
    );
    final writer=WaffraVerifiedGoalDueSnapshotWriter(
      store:db,snapshot:snapshot,experimentalEnabled:true);
    final receipt=await writer.settle(
      goalId:'goal',recurringId:'rent',dueKey:'rec_rent_2026_11',
      amountMinor:20000,confirmedAtIso:'2026-11-02T12:00:00',
      userConfirmed:true,
    );
    expect(receipt.alreadySettled,false);
    expect(receipt.fromGoalMinor,15000);
    expect(receipt.fromCurrentMinor,5000);
    expect(await count('fresh_finance_entries'),1);
    expect(await count('fresh_finance_goal_due_settlements'),1);
    final after=await snapshot.read();
    expect(after.generation,2);
    final entries=jsonDecode(after.values['entries'] as String) as List;
    expect(entries.length,1);
    expect(entries.single['sourceType'],'goal_due');
    final goals=jsonDecode(after.values['waffra_goals_v24'] as String) as List;
    expect(goals.single['saved'],0.0);
    final recurring=jsonDecode(after.values['waffra_recurring_v24'] as String)
      as List;
    expect(recurring.single['active'],false);
    final repeated=await writer.settle(
      goalId:'goal',recurringId:'rent',dueKey:'rec_rent_2026_11',
      amountMinor:20000,confirmedAtIso:'2026-11-02T13:00:00',
      userConfirmed:true,
    );
    expect(repeated.alreadySettled,true);
    expect((await snapshot.read()).generation,2);
    expect(await count('fresh_finance_entries'),1);
  });

  test('M365 stale snapshot denies goal due and leaves both stores unchanged',
      () async {
    await bootstrap();
    await addGoal();
    await addRecurring();
    final snapshot=WaffraAtomicFinanceSnapshot(
      store:db,experimentalEnabled:true);
    await snapshot.initializeEmpty();
    await snapshot.commit(expectedGeneration:0,fullFinanceSnapshot:{
      'entries':'[]',
      'waffra_goals_v24':jsonEncode([
        {'id':'goal','name':'هدف الادخار',
         'target':300.0,'saved':149.99},
      ]),
      'waffra_recurring_v24':jsonEncode([
        {'id':'rent','title':'سداد الهدف','category':'سكن / إيجار',
         'amount':200.0,'income':false,'day':1,'active':true,
         'startAt':'2026-11-01T00:00:00','linkedGoalId':'goal'},
      ]),
    });
    final writer=WaffraVerifiedGoalDueSnapshotWriter(
      store:db,snapshot:snapshot,experimentalEnabled:true);
    await expectLater(writer.settle(
      goalId:'goal',recurringId:'rent',dueKey:'rec_rent_2026_11',
      amountMinor:20000,confirmedAtIso:'2026-11-02T12:00:00',
      userConfirmed:true,
    ),throwsA(isA<StateError>()));
    expect(await count('fresh_finance_entries'),0);
    expect(await count('fresh_finance_goal_due_settlements'),0);
    expect(await count('fresh_finance_goal_wallet_movements'),0);
    expect((await snapshot.read()).generation,1);
    expect((await db.customSelect(
      "SELECT saved_minor FROM fresh_finance_goals WHERE goal_id='goal'",
    ).getSingle()).read<int>('saved_minor'),15000);
  });

}
