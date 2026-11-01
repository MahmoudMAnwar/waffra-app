import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import 'waffra_encrypted_store.dart';
import 'waffra_fresh_finance_domain_schema.dart';

class WaffraFinanceDomainLegacyImportReceipt {
  const WaffraFinanceDomainLegacyImportReceipt({
    required this.namedBudgetsCreated,
    required this.budgetLinksCreated,
    required this.goalOpeningsCreated,
    required this.unresolvedBudgetLinks,
  });
  final int namedBudgetsCreated;
  final int budgetLinksCreated;
  final int goalOpeningsCreated;
  /// These original references remain in entry.source_json, never deleted.
  /// Any nonzero value BLOCKS certified production cutover until reviewed.
  final int unresolvedBudgetLinks;
}

/// A non-destructive, user-authorized migration of already-staged encrypted
/// category/goal/entry snapshots to independent SQLCipher finance entities.
/// NEVER runs on startup or auto-selects the new ledger. No fake history rows.
class WaffraFinanceDomainLegacyImporter {
  const WaffraFinanceDomainLegacyImporter({
    required this.store,
    this.experimentalEnabled=false,
  });

  final WaffraEncryptedStore store;
  final bool experimentalEnabled;

  static Map<String,dynamic> _json(String raw) {
    final value=jsonDecode(raw);
    if(value is! Map)throw StateError('Invalid historical finance JSON.');
    return Map<String,dynamic>.from(value);
  }

  static int _minor(Object? value) {
    if(value is! num || !value.isFinite || value<0 ||
       value>90071992547409) {
      throw StateError('Unrepresentable historical money.');
    }
    final raw=value*100, rounded=raw.round();
    if((raw-rounded).abs()>0.00001) {
      throw StateError('Historical amount has excess precision.');
    }
    return rounded;
  }

  Future<WaffraFinanceDomainLegacyImportReceipt> importCapturedDomain({
    required bool explicitlyAuthorized,
    required String importedAtIso,
  }) async {
    if(!experimentalEnabled || !explicitlyAuthorized) {
      throw StateError('Encrypted domain migration needs explicit approval.');
    }
    if(DateTime.tryParse(importedAtIso)==null) {
      throw ArgumentError('Migration timestamp missing.');
    }
    await WaffraFreshFinanceDomainSchema.requireReady(store);
    return store.transaction(() async {
      var createdBudgets=0,createdLinks=0,createdOpenings=0,unresolved=0;
      final categories=await store.customSelect(
        'SELECT category_id,name,parent_id,is_income,budget_minor,source_json '
        'FROM fresh_finance_categories',
      ).get();
      final migratedBudgetByCategory=<String,String>{};
      for(final category in categories){
        final budgetMinor=category.read<int>('budget_minor');
        if(budgetMinor<=0)continue;
        if(category.read<int>('is_income')!=0) {
          throw StateError('An income category has an expense budget.');
        }
        final categoryId=category.read<String>('category_id');
        final source=_json(category.read<String>('source_json'));
        if(_minor(source['budget']??0)!=budgetMinor) {
          throw StateError('Category budget canonical mismatch.');
        }
        final requestedName=source['budgetLabel'];
        final label=requestedName is String && requestedName.trim().isNotEmpty
          ? requestedName.trim() : 'ميزانية ${category.read<String>('name')}';
        final active=source['budgetActive'] != false;
        final rawAlert=source['alertPercent'];
        final alert=rawAlert is int && rawAlert>0 && rawAlert<=100
          ? rawAlert : 80;
        final budgetId='legacy-budget:$categoryId';
        migratedBudgetByCategory[categoryId]=budgetId;
        final prior=await store.customSelect(
          'SELECT budget_id,category_id,monthly_limit_minor,is_active '
          'FROM fresh_finance_named_budgets WHERE legacy_category_id=?',
          variables:[Variable.withString(categoryId)],
        ).get();
        if(prior.isNotEmpty){
          final row=prior.single;
          if(row.read<String>('budget_id')!=budgetId ||
             row.read<String>('category_id')!=categoryId ||
             row.read<int>('monthly_limit_minor')!=budgetMinor ||
             row.read<int>('is_active')!=(active?1:0)){
            throw StateError('Previously imported legacy budget changed.');
          }
          continue;
        }
        await store.customStatement(
          'INSERT INTO fresh_finance_named_budgets '
          '(budget_id,name,category_id,monthly_limit_minor,is_active,'
          'alert_percent,created_at_iso,legacy_category_id,source_json) '
          'VALUES (?,?,?,?,?,?,?,?,?)',
          [budgetId,label,categoryId,budgetMinor,active?1:0,alert,
           importedAtIso,categoryId,jsonEncode({
             'id':budgetId,'name':label,'categoryId':categoryId,
             'budgetMinor':budgetMinor,'active':active,
             'legacyCategoryId':categoryId,
             'provenance':'imported from verified category snapshot',
           })],
        );
        createdBudgets++;
      }

      final entries=await store.customSelect(
        'SELECT entry_id,amount_minor,is_income,source_json '
        'FROM fresh_finance_entries',
      ).get();
      for(final entry in entries){
        final source=_json(entry.read<String>('source_json'));
        final legacyLink=source['budgetId'];
        if(legacyLink==null || legacyLink=='')continue;
        if(legacyLink is! String) {
          throw StateError('Non-string historical budget link.');
        }
        if(entry.read<int>('is_income')!=0 ||
           _minor(source['amount'])!=entry.read<int>('amount_minor')){
          throw StateError('Legacy allocated expense does not match ledger.');
        }
        final budgetId=migratedBudgetByCategory[legacyLink];
        if(budgetId==null || entry.read<int>('amount_minor')<=0){
          unresolved++;
          // Retained in source_json; never silently guess a new budget.
          continue;
        }
        final entryId=entry.read<String>('entry_id');
        final allocationId='legacy-budget-assignment:$entryId';
        final prior=await store.customSelect(
          'SELECT budget_id,entry_id,amount_minor '
          'FROM fresh_finance_budget_allocations WHERE allocation_id=?',
          variables:[Variable.withString(allocationId)],
        ).get();
        if(prior.isNotEmpty){
          final row=prior.single;
          if(row.read<String>('budget_id')!=budgetId ||
             row.read<String>('entry_id')!=entryId ||
             row.read<int>('amount_minor')!=entry.read<int>('amount_minor')) {
            throw StateError('Historical budget allocation collision.');
          }
          continue;
        }
        await store.customStatement(
          'INSERT INTO fresh_finance_budget_allocations '
          '(allocation_id,budget_id,entry_id,amount_minor,'
          'explicitly_confirmed,assigned_at_iso) VALUES (?,?,?,?,1,?)',
          [allocationId,budgetId,entryId,entry.read<int>('amount_minor'),
           importedAtIso],
        );
        createdLinks++;
      }

      final goals=await store.customSelect(
        'SELECT goal_id,saved_minor,source_json FROM fresh_finance_goals',
      ).get();
      for(final row in goals){
        final goalId=row.read<String>('goal_id');
        final snapshot=row.read<String>('source_json');
        final source=_json(snapshot);
        final saved=row.read<int>('saved_minor');
        if(_minor(source['saved']??0)!=saved) {
          throw StateError('Legacy goal savings do not match typed SQL.');
        }
        final digest=sha256.convert(utf8.encode(snapshot)).toString();
        final prior=await store.customSelect(
          'SELECT saved_minor,source_digest FROM '
          'fresh_finance_goal_opening_balances WHERE goal_id=?',
          variables:[Variable.withString(goalId)],
        ).get();
        if(prior.isNotEmpty){
          if(prior.single.read<int>('saved_minor')!=saved ||
             prior.single.read<String>('source_digest')!=digest){
            throw StateError('Opening witness changed after migration.');
          }
          continue;
        }
        await store.customStatement(
          'INSERT INTO fresh_finance_goal_opening_balances '
          '(goal_id,saved_minor,source_digest,witnessed_at_iso) '
          'VALUES (?,?,?,?)',
          [goalId,saved,digest,importedAtIso],
        );
        createdOpenings++;
      }
      return WaffraFinanceDomainLegacyImportReceipt(
        namedBudgetsCreated:createdBudgets,
        budgetLinksCreated:createdLinks,
        goalOpeningsCreated:createdOpenings,
        unresolvedBudgetLinks:unresolved,
      );
    });
  }
}
