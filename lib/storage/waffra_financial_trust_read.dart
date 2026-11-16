import 'package:drift/drift.dart';

import '../waffra_financial_trust_policy.dart';
import 'waffra_accounts_repository.dart';
import 'waffra_accounts_schema.dart';
import 'waffra_encrypted_store.dart';

/// Independently reconstructs every account balance from SQLCipher posting
/// sources while under the production verified metadata read lock.
/// The projection never stages a migration, repairs money or writes a balance.
abstract final class WaffraFinancialTrustRead {
 static Future<WaffraTrustScan> inspect(WaffraEncryptedStore store) async {
  await WaffraAccountsSchema.requireReady(store);
  final actual=await WaffraAccountsRepository(
   db:store,experimentalEnabled:true).balances();
  final opening=await store.customSelect(
   'SELECT account_id,opening_minor FROM fresh_finance_money_accounts').get();
  final entryRows=await store.customSelect('''
SELECT l.account_id,COALESCE(SUM(
 CASE WHEN e.is_income=1 THEN e.amount_minor
      WHEN d.entry_id IS NOT NULL THEN -d.current_cash_minor
      ELSE -e.amount_minor END),0) AS delta_minor
FROM fresh_finance_account_entry_links l
JOIN fresh_finance_entries e ON e.entry_id=l.entry_id
LEFT JOIN fresh_finance_goal_due_settlements d ON d.entry_id=e.entry_id
GROUP BY l.account_id
''').get();
  final transfers=await store.customSelect('''
SELECT account_id,SUM(delta_minor) AS delta_minor FROM (
 SELECT to_account_id AS account_id,amount_minor AS delta_minor
 FROM fresh_finance_internal_transfers
 UNION ALL
 SELECT from_account_id AS account_id,-amount_minor AS delta_minor
 FROM fresh_finance_internal_transfers
) GROUP BY account_id
''').get();
  final goals=await store.customSelect('''
SELECT s.account_id,COALESCE(SUM(CASE
 WHEN m.kind='fund' THEN -m.amount_minor
 WHEN m.kind='release' THEN m.amount_minor ELSE 0 END),0) AS delta_minor
FROM fresh_finance_goal_account_sources s
JOIN fresh_finance_goal_wallet_movements m
 ON m.movement_id=s.movement_id
GROUP BY s.account_id
''').get();
  final unassigned=await store.customSelect('''
SELECT COUNT(*) AS n,COALESCE(SUM(CASE WHEN e.is_income=1
 THEN e.amount_minor ELSE -e.amount_minor END),0) AS net_minor
FROM fresh_finance_entries e
WHERE NOT EXISTS(SELECT 1 FROM fresh_finance_account_entry_links l
 WHERE l.entry_id=e.entry_id)
''').getSingle();
  final transferCount=await store.customSelect(
   'SELECT COUNT(*) AS n FROM fresh_finance_internal_transfers'
  ).getSingle();
  Map<String,int> grouped(List<QueryRow> rows) => {
   for(final row in rows)
    row.read<String>('account_id'):row.read<int>('delta_minor'),
  };
  final entriesByAccount=grouped(entryRows);
  final transfersByAccount=grouped(transfers);
  final goalsByAccount=grouped(goals);
  final openingByAccount={
   for(final row in opening)
    row.read<String>('account_id'):row.read<int>('opening_minor'),
  };
  final validIds=openingByAccount.keys.toSet();
  if(actual.length!=validIds.length||
   entriesByAccount.keys.any((id)=>!validIds.contains(id))||
   transfersByAccount.keys.any((id)=>!validIds.contains(id))||
   goalsByAccount.keys.any((id)=>!validIds.contains(id))) {
   throw StateError('Account source or financial association missing.');
  }
  final checks=<WaffraTrustAccountResult>[];
  for(final balance in actual) {
   final start=openingByAccount[balance.id];
   if(start==null)throw StateError('Missing verified account opening.');
   final expected=start+(entriesByAccount[balance.id]??0)+
    (transfersByAccount[balance.id]??0)+
    (goalsByAccount[balance.id]??0);
   checks.add(WaffraTrustAccountResult(
    id:balance.id,name:balance.name,actualMinor:balance.balanceMinor,
    expectedMinor:expected,openingMinor:start));
  }
  return WaffraTrustScan(
   accounts:List.unmodifiable(checks),
   unassignedEntries:unassigned.read<int>('n'),
   unassignedNetMinor:unassigned.read<int>('net_minor'),
   transferCount:transferCount.read<int>('n'),
   checkedAt:DateTime.now());
 }
}
