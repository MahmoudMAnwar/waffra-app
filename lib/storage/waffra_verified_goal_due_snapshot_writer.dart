import 'dart:convert';

import 'package:drift/drift.dart';

import 'waffra_atomic_finance_snapshot.dart';
import 'waffra_encrypted_store.dart';
import 'waffra_fresh_finance_domain_repository.dart';

/// One encrypted SQL transaction for both typed goal settlement AND the
/// canonical financial snapshot consumed by Home and the Android widget.
///
/// This does not activate SQLCipher or open a production vault. The caller must
/// first own the app/widget native finance writer lock, a verified source
/// witness and explicit confirmation. Never use a separate legacy write.
class WaffraVerifiedGoalDueSnapshotWriter {
  const WaffraVerifiedGoalDueSnapshotWriter({
    required this.store,
    required this.snapshot,
    this.experimentalEnabled = false,
  });

  final WaffraEncryptedStore store;
  final WaffraAtomicFinanceSnapshot snapshot;
  final bool experimentalEnabled;

  static List<Map<String, dynamic>> _list(Object? value, String field) {
    if (value is! String) {
      throw StateError('Missing canonical finance field: ' + field);
    }
    final decoded = jsonDecode(value);
    if (decoded is! List) {
      throw StateError('Invalid canonical finance list: ' + field);
    }
    return [
      for (final item in decoded)
        if (item is Map<String, dynamic>)
          Map<String, dynamic>.from(item)
        else
          throw StateError('Invalid canonical entity: ' + field),
    ];
  }

  static Map<String, dynamic> _unique(
    List<Map<String, dynamic>> records, String id, String label,
  ) {
    final matching=records.where((row)=>row['id']==id).toList();
    if (matching.length!=1) {
      throw StateError('Missing or duplicate canonical ' + label);
    }
    return matching.single;
  }

  static int _minor(Object? value) {
    if (value is! num || !value.isFinite || value < 0) {
      throw StateError('Invalid canonical money balance.');
    }
    final cents=value*100;
    final rounded=cents.round();
    if ((cents-rounded).abs()>0.00001) {
      throw StateError('Invalid canonical money precision.');
    }
    return rounded;
  }

  Future<WaffraGoalDueSqlReceipt> settle({
    required String goalId,
    required String recurringId,
    required String dueKey,
    required int amountMinor,
    required String confirmedAtIso,
    required bool userConfirmed,
  }) async {
    if (!experimentalEnabled || !userConfirmed) {
      throw StateError('Verified encrypted goal due needs explicit approval.');
    }
    // Both the typed writer and the Home/Widget snapshot MUST share the
    // identical SQL connection; two different vaults cannot commit atomically.
    if (!identical(snapshot.store, store)) {
      throw StateError('Goal settlement and finance snapshot use different vaults.');
    }
    return store.transaction(() async {
      final before=await snapshot.read();
      final finance=Map<String,Object?>.from(before.values);
      final ledger=_list(finance['entries'],'entries');
      final goals=_list(finance['waffra_goals_v24'],'goals');
      final schedules=_list(finance['waffra_recurring_v24'],'recurring');
      final goal=_unique(goals,goalId,'goal');
      final recurring=_unique(schedules,recurringId,'recurring');
      if (recurring['linkedGoalId']!=goalId ||
          recurring['income']!=false ||
          _minor(recurring['amount'])!=amountMinor ||
          recurring['startAt'] is! String) {
        throw StateError('Canonical recurring goal identity differs.');
      }

      final savedBefore=_minor(goal['saved']??0);
      final sqlGoal=await store.customSelect(
        'SELECT saved_minor,source_json FROM fresh_finance_goals WHERE goal_id=?',
        variables:[Variable.withString(goalId)],
      ).get();
      final sqlRecurring=await store.customSelect(
        'SELECT source_json FROM fresh_finance_recurring WHERE recurring_id=?',
        variables:[Variable.withString(recurringId)],
      ).get();
      if (sqlGoal.length!=1 || sqlRecurring.length!=1 ||
          sqlGoal.single.read<int>('saved_minor')!=savedBefore) {
        throw StateError('Canonical and typed goal balances differ.');
      }
      final typedRecurring=jsonDecode(sqlRecurring.single.read<String>('source_json'));
      if (typedRecurring is! Map ||
          typedRecurring['startAt']!=recurring['startAt'] ||
          typedRecurring['linkedGoalId']!=goalId ||
          typedRecurring['active']!=recurring['active']) {
        throw StateError('Canonical and typed recurring schedules differ.');
      }

      final existing=ledger.where((entry)=>entry['id']==dueKey).toList();
      if (existing.length>1) {
        throw StateError('Duplicate due event in canonical ledger.');
      }
      if (existing.isEmpty && recurring['active']!=true) {
        throw StateError('Inactive canonical recurring event cannot post.');
      }
      final domain=WaffraFreshFinanceDomainRepository(
        store:store,experimentalEnabled:true,
      );
      // Nested SQL transactions are one atomic outer commit. An exception in
      // snapshot.commit rolls back the typed transaction, linked recurring
      // change, movement and due-settlement receipt together.
      final receipt=await domain.settleLinkedGoalDue(
        goalId:goalId,recurringId:recurringId,dueKey:dueKey,
        amountMinor:amountMinor,confirmedAtIso:confirmedAtIso,
        userConfirmed:true,
      );
      if (receipt.alreadySettled) {
        if (existing.length!=1 || recurring['active']!=false ||
            _minor(goal['saved']??0)!=sqlGoal.single.read<int>('saved_minor')) {
          throw StateError('Typed due already paid but canonical snapshot diverged.');
        }
        return receipt;
      }
      if (existing.isNotEmpty || receipt.fromGoalMinor>savedBefore ||
          receipt.fromGoalMinor+receipt.fromCurrentMinor!=amountMinor) {
        throw StateError('Inconsistent goal due ledger split.');
      }

      final inserted=await store.customSelect(
        'SELECT source_json FROM fresh_finance_entries WHERE entry_id=?',
        variables:[Variable.withString(dueKey)],
      ).get();
      if (inserted.length!=1) {
        throw StateError('Goal due ledger row was not committed.');
      }
      final entry=jsonDecode(inserted.single.read<String>('source_json'));
      if (entry is! Map<String,dynamic> ||
          entry['id']!=dueKey || entry['sourceType']!='goal_due' ||
          entry['income']!=false || _minor(entry['amount'])!=amountMinor) {
        throw StateError('Goal due entry mismatches its SQL settlement.');
      }
      goal['saved']=(savedBefore-receipt.fromGoalMinor)/100;
      recurring['active']=false;
      finance['entries']=jsonEncode([entry,...ledger]);
      finance['waffra_goals_v24']=jsonEncode(goals);
      finance['waffra_recurring_v24']=jsonEncode(schedules);
      final committed=await snapshot.commit(
        expectedGeneration:before.generation,
        fullFinanceSnapshot:finance,
      );
      if (committed.generation!=before.generation+1) {
        throw StateError('Canonical snapshot revision did not advance.');
      }
      return receipt;
    });
  }
}
