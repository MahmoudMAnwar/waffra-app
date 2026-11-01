import 'dart:convert';

import 'package:drift/drift.dart';

import 'waffra_encrypted_store.dart';
import 'waffra_fresh_finance_domain_schema.dart';

/// A saved, immutable receipt for exactly one user-confirmed linked goal due.
class WaffraGoalDueSqlReceipt {
  const WaffraGoalDueSqlReceipt({
    required this.entryId,
    required this.amountMinor,
    required this.fromGoalMinor,
    required this.fromCurrentMinor,
    required this.alreadySettled,
  });

  final String entryId;
  final int amountMinor;
  final int fromGoalMinor;
  final int fromCurrentMinor;
  final bool alreadySettled;
}

/// Candidate relational financial writer. Existing app/Widget writers MUST
/// NOT route here before the independent production cutover and backup gate.
/// Unlike two independent SharedPreferences saves, every method below uses
/// one SQLCipher transaction and never falls back to legacy storage.
class WaffraFreshFinanceDomainRepository {
  const WaffraFreshFinanceDomainRepository({
    required this.store,
    this.experimentalEnabled = false,
  });

  final WaffraEncryptedStore store;
  final bool experimentalEnabled;

  static void _id(String value, String label) {
    if (value.trim().isEmpty || value.length > 256) {
      throw ArgumentError.value(value, label, 'Invalid identifier.');
    }
  }

  static DateTime _iso(String value) {
    final date = DateTime.tryParse(value);
    if (date == null || value.length < 10) {
      throw ArgumentError.value(value, 'timestamp', 'Invalid ISO datetime.');
    }
    return date;
  }

  static int _minor(Object? value) {
    if (value is! num || !value.isFinite || value < 0 ||
        value > 90071992547409) {
      throw StateError('Invalid saved money amount.');
    }
    final scaled = value * 100;
    final rounded = scaled.round();
    if ((scaled - rounded).abs() > 0.00001) {
      throw StateError('Excess precision in saved money.');
    }
    return rounded;
  }

  static Map<String, dynamic> _decoded(String raw) {
    final parsed = jsonDecode(raw);
    if (parsed is! Map) throw StateError('Invalid stored JSON object.');
    return Map<String, dynamic>.from(parsed);
  }

  Future<void> _requireReady() async {
    if (!experimentalEnabled) {
      throw StateError('Production SQLCipher finance cutover is not approved.');
    }
    await WaffraFreshFinanceDomainSchema.requireReady(store);
  }

  /// New named budgets are independent rows. No uniqueness on category ID:
  /// a single subcategory may have multiple separately named budgets.
  Future<void> createNamedBudget({
    required String budgetId,
    required String name,
    required String categoryId,
    required int limitMinor,
    required String createdAtIso,
    int alertPercent = 80,
    bool active = true,
  }) async {
    await _requireReady();
    _id(budgetId, 'budgetId');
    _id(categoryId, 'categoryId');
    _iso(createdAtIso);
    if (name.trim().isEmpty || name.length > 80 ||
        limitMinor <= 0 || alertPercent < 1 || alertPercent > 100) {
      throw ArgumentError('Invalid named budget.');
    }
    await store.transaction(() async {
      final category = await store.customSelect(
        'SELECT is_income,parent_id FROM fresh_finance_categories '
        'WHERE category_id=?',
        variables: [Variable.withString(categoryId)],
      ).get();
      if (category.length != 1 || category.single.read<int>('is_income') != 0 ||
          (category.single.read<String?>('parent_id') ?? '').isEmpty) {
        throw StateError('Budget must belong to a saved expense subcategory.');
      }
      await store.customStatement(
        'INSERT INTO fresh_finance_named_budgets '
        '(budget_id,name,category_id,monthly_limit_minor,is_active,'
        'alert_percent,created_at_iso,source_json) VALUES (?,?,?,?,?,?,?,?)',
        [budgetId,name.trim(),categoryId,limitMinor,active ? 1 : 0,
         alertPercent,createdAtIso,jsonEncode({
          'id':budgetId,'name':name.trim(),'categoryId':categoryId,
          'budgetMinor':limitMinor,'active':active,'alertPercent':alertPercent,
        })],
      );
    });
  }

  /// A paused budget is retained with all its old confirmed allocations.
  /// Re-enabling it NEVER retroactively attaches older/unassigned entries.
  Future<void> setBudgetActive(String budgetId, bool active) async {
    await _requireReady();
    _id(budgetId, 'budgetId');
    await store.transaction(() async {
      final rows = await store.customSelect(
        'SELECT source_json FROM fresh_finance_named_budgets WHERE budget_id=?',
        variables: [Variable.withString(budgetId)],
      ).get();
      if (rows.length != 1) throw StateError('Budget does not exist.');
      final source = _decoded(rows.single.read<String>('source_json'))
        ..['active'] = active;
      await store.customStatement(
        'UPDATE fresh_finance_named_budgets SET is_active=?,source_json=? '
        'WHERE budget_id=?',
        [active ? 1 : 0,jsonEncode(source),budgetId],
      );
    });
  }

  /// Only explicit user confirmation writes an allocation. Allocations never
  /// change the source transaction's amount and never exceed that amount.
  Future<void> assignExpenseToBudget({
    required String allocationId,
    required String entryId,
    required String budgetId,
    required int allocatedMinor,
    required String assignedAtIso,
    required bool userConfirmed,
    bool crossCategoryApproved = false,
  }) async {
    await _requireReady();
    _id(allocationId, 'allocationId');
    _id(entryId, 'entryId');
    _id(budgetId, 'budgetId');
    _iso(assignedAtIso);
    if (!userConfirmed || allocatedMinor <= 0) {
      throw StateError('Budget assignment needs explicit confirmation.');
    }
    await store.transaction(() async {
      final budget = await store.customSelect(
        'SELECT category_id,is_active FROM fresh_finance_named_budgets '
        'WHERE budget_id=?',
        variables: [Variable.withString(budgetId)],
      ).get();
      final entry = await store.customSelect(
        'SELECT category_id,is_income,amount_minor FROM fresh_finance_entries '
        'WHERE entry_id=?',
        variables: [Variable.withString(entryId)],
      ).get();
      if (budget.length != 1 || budget.single.read<int>('is_active') != 1) {
        throw StateError('Budget is missing or paused.');
      }
      if (entry.length != 1 || entry.single.read<int>('is_income') != 0) {
        throw StateError('Only saved expenses may use a budget.');
      }
      final matched = budget.single.read<String>('category_id') ==
        entry.single.read<String?>('category_id');
      if (!matched && !crossCategoryApproved) {
        throw StateError('Expense category differs; explicit review required.');
      }
      final allocated = await store.customSelect(
        'SELECT COALESCE(SUM(amount_minor),0) AS n '
        'FROM fresh_finance_budget_allocations WHERE entry_id=?',
        variables: [Variable.withString(entryId)],
      ).getSingle();
      if (allocated.read<int>('n') + allocatedMinor >
          entry.single.read<int>('amount_minor')) {
        throw StateError('Allocations exceed the original expense.');
      }
      await store.customStatement(
        'INSERT INTO fresh_finance_budget_allocations '
        '(allocation_id,budget_id,entry_id,amount_minor,'
        'explicitly_confirmed,assigned_at_iso) VALUES (?,?,?,?,1,?)',
        [allocationId,budgetId,entryId,allocatedMinor,assignedAtIso],
      );
    });
  }

  /// Historical goal.saved is an opening witness, NOT fake contribution events.
  Future<void> attestGoalOpening({
    required String goalId,
    required int savedMinor,
    required String sourceDigest,
    required String witnessedAtIso,
  }) async {
    await _requireReady();
    _id(goalId, 'goalId');
    _iso(witnessedAtIso);
    if (savedMinor < 0 || sourceDigest.length < 16) {
      throw ArgumentError('Invalid goal opening witness.');
    }
    await store.transaction(() async {
      final row = await store.customSelect(
        'SELECT saved_minor FROM fresh_finance_goals WHERE goal_id=?',
        variables: [Variable.withString(goalId)],
      ).get();
      if (row.length != 1 || row.single.read<int>('saved_minor') != savedMinor) {
        throw StateError('Goal opening balance differs from saved finance.');
      }
      await store.customStatement(
        'INSERT INTO fresh_finance_goal_opening_balances '
        '(goal_id,saved_minor,source_digest,witnessed_at_iso) VALUES (?,?,?,?)',
        [goalId,savedMinor,sourceDigest,witnessedAtIso],
      );
    });
  }

  /// Earmarking is not an expense. No spendable-cash cap: explicit negative
  /// cash warning belongs to the UI, and the domain writer must not refuse
  /// an otherwise valid user-confirmed allocation for low available cash.
  Future<bool> updateGoalSavings({
    required String movementId,
    required String goalId,
    required int amountMinor,
    required bool release,
    required String idempotencyKey,
    required String occurredAtIso,
    required bool userConfirmed,
  }) async {
    await _requireReady();
    _id(movementId, 'movementId');
    _id(goalId, 'goalId');
    _id(idempotencyKey, 'idempotencyKey');
    _iso(occurredAtIso);
    if (!userConfirmed || amountMinor <= 0) {
      throw StateError('Goal movement must be user-confirmed and positive.');
    }
    return store.transaction(() async {
      final prior = await store.customSelect(
        'SELECT goal_id,kind,amount_minor FROM '
        'fresh_finance_goal_wallet_movements WHERE idempotency_key=?',
        variables: [Variable.withString(idempotencyKey)],
      ).get();
      if (prior.isNotEmpty) {
        if (prior.length != 1 ||
            prior.single.read<String>('goal_id') != goalId ||
            prior.single.read<String>('kind') != (release ? 'release' : 'fund') ||
            prior.single.read<int>('amount_minor') != amountMinor) {
          throw StateError('Goal idempotency key conflict.');
        }
        return false;
      }
      final rows = await store.customSelect(
        'SELECT saved_minor,source_json FROM fresh_finance_goals WHERE goal_id=?',
        variables: [Variable.withString(goalId)],
      ).get();
      if (rows.length != 1) throw StateError('Goal does not exist.');
      final saved = rows.single.read<int>('saved_minor');
      final source = _decoded(rows.single.read<String>('source_json'));
      if (_minor(source['saved'] ?? 0) != saved) {
        throw StateError('Goal canonical and typed balances disagree.');
      }
      final updated = release ? saved - amountMinor : saved + amountMinor;
      if (updated < 0 || updated > 9007199254740991) {
        throw StateError('Goal movement exceeds permitted balance.');
      }
      source['saved'] = updated / 100;
      await store.customStatement(
        'UPDATE fresh_finance_goals SET saved_minor=?,source_json=? '
        'WHERE goal_id=?',
        [updated,jsonEncode(source),goalId],
      );
      await store.customStatement(
        'INSERT INTO fresh_finance_goal_wallet_movements '
        '(movement_id,goal_id,kind,amount_minor,idempotency_key,occurred_at_iso) '
        'VALUES (?,?,?,?,?,?)',
        [movementId,goalId,release ? 'release' : 'fund',amountMinor,
         idempotencyKey,occurredAtIso],
      );
      return true;
    });
  }

  /// One SQLCipher transaction: append the actual expense, debit earmarked
  /// savings, deactivate the *one-time* recurring plan, and write an immutable
  /// settlement plus optional goal-wallet debit event. Any failure rolls back
  /// ALL five changes. A second click returns the stored same due receipt.
  Future<WaffraGoalDueSqlReceipt> settleLinkedGoalDue({
    required String goalId,
    required String recurringId,
    required String dueKey,
    required int amountMinor,
    required String confirmedAtIso,
    required bool userConfirmed,
  }) async {
    await _requireReady();
    _id(goalId, 'goalId');
    _id(recurringId, 'recurringId');
    _id(dueKey, 'dueKey');
    final now = _iso(confirmedAtIso);
    if (!userConfirmed || amountMinor <= 0) {
      throw StateError('Goal due payment needs explicit confirmation.');
    }
    return store.transaction(() async {
      final already = await store.customSelect(
        'SELECT goal_id,recurring_id,entry_id,amount_minor,goal_wallet_minor,'
        'current_cash_minor FROM fresh_finance_goal_due_settlements '
        'WHERE due_key=?',
        variables: [Variable.withString(dueKey)],
      ).get();
      if (already.isNotEmpty) {
        final row = already.single;
        if (row.read<String>('goal_id') != goalId ||
            row.read<String>('recurring_id') != recurringId ||
            row.read<String>('entry_id') != dueKey ||
            row.read<int>('amount_minor') != amountMinor) {
          throw StateError('Conflicting settlement for previously paid due.');
        }
        return WaffraGoalDueSqlReceipt(
          entryId: dueKey, amountMinor: amountMinor,
          fromGoalMinor: row.read<int>('goal_wallet_minor'),
          fromCurrentMinor: row.read<int>('current_cash_minor'),
          alreadySettled: true,
        );
      }
      final goals = await store.customSelect(
        'SELECT saved_minor,source_json FROM fresh_finance_goals WHERE goal_id=?',
        variables: [Variable.withString(goalId)],
      ).get();
      final schedules = await store.customSelect(
        'SELECT amount_minor,is_income,source_json FROM fresh_finance_recurring '
        'WHERE recurring_id=?',
        variables: [Variable.withString(recurringId)],
      ).get();
      if (goals.length != 1 || schedules.length != 1) {
        throw StateError('Linked goal and recurring schedule must both exist.');
      }
      final schedule = _decoded(schedules.single.read<String>('source_json'));
      final goal = _decoded(goals.single.read<String>('source_json'));
      final dueDate = DateTime.tryParse('${schedule['startAt'] ?? ''}');
      if (dueDate == null) throw StateError('Original due date is missing.');
      final expectedDue = 'rec_${recurringId}_${dueDate.year}_'
          '${dueDate.month.toString().padLeft(2,'0')}';
      if (dueKey != expectedDue || schedule['linkedGoalId'] != goalId ||
          schedule['active'] == false || schedule['income'] != false ||
          schedules.single.read<int>('is_income') != 0 ||
          schedules.single.read<int>('amount_minor') != amountMinor ||
          _minor(schedule['amount']) != amountMinor ||
          now.isBefore(DateTime(dueDate.year,dueDate.month,dueDate.day))) {
        throw StateError('Linked due identity, amount or schedule has changed.');
      }
      final saved = goals.single.read<int>('saved_minor');
      if (_minor(goal['saved'] ?? 0) != saved) {
        throw StateError('Goal saved balance differs from encrypted source.');
      }
      final category = schedule['category'];
      if (category is! String || category.trim().isEmpty) {
        throw StateError('Goal due expense category is missing.');
      }
      final exists = await store.customSelect(
        'SELECT entry_id FROM fresh_finance_entries WHERE entry_id=?',
        variables: [Variable.withString(dueKey)],
      ).get();
      if (exists.isNotEmpty) {
        throw StateError('Existing ledger entry has no matching settlement.');
      }
      final fromGoal = saved < amountMinor ? saved : amountMinor;
      final fromCurrent = amountMinor - fromGoal;
      final canonicalEntry = <String, Object?>{
        'id':dueKey,'title':schedule['title'] ?? 'Goal due',
        'category':category,'amount':amountMinor / 100,
        'income':false,'date':confirmedAtIso,
        'sourceType':'goal_due','budgetId':null,
        'notes':'goal_wallet_minor=$fromGoal;current_cash_minor=$fromCurrent',
      };
      await store.customStatement(
        'INSERT INTO fresh_finance_entries '
        '(entry_id,title,category_snapshot,amount_minor,is_income,'
        'occurred_iso,receipt_count,source_json) VALUES (?,?,?,?,0,?,0,?)',
        [dueKey,canonicalEntry['title'],category,amountMinor,confirmedAtIso,
         jsonEncode(canonicalEntry)],
      );
      goal['saved'] = (saved - fromGoal) / 100;
      schedule['active'] = false;
      await store.customStatement(
        'UPDATE fresh_finance_goals SET saved_minor=?,source_json=? '
        'WHERE goal_id=?',
        [saved - fromGoal,jsonEncode(goal),goalId],
      );
      await store.customStatement(
        'UPDATE fresh_finance_recurring SET source_json=? WHERE recurring_id=?',
        [jsonEncode(schedule),recurringId],
      );
      await store.customStatement(
        'INSERT INTO fresh_finance_goal_due_settlements '
        '(due_key,goal_id,recurring_id,entry_id,amount_minor,goal_wallet_minor,'
        'current_cash_minor,confirmed_at_iso) VALUES (?,?,?,?,?,?,?,?)',
        [dueKey,goalId,recurringId,dueKey,amountMinor,fromGoal,
         fromCurrent,confirmedAtIso],
      );
      if (fromGoal > 0) {
        await store.customStatement(
          'INSERT INTO fresh_finance_goal_wallet_movements '
          '(movement_id,goal_id,kind,amount_minor,idempotency_key,'
          'linked_entry_id,occurred_at_iso) VALUES (?,?,?,?,?,?,?)',
          ['due-debit:$dueKey',goalId,'due_debit',fromGoal,
           'due-debit:$dueKey',dueKey,confirmedAtIso],
        );
      }
      return WaffraGoalDueSqlReceipt(
        entryId:dueKey,amountMinor:amountMinor,fromGoalMinor:fromGoal,
        fromCurrentMinor:fromCurrent,alreadySettled:false,
      );
    });
  }
}
