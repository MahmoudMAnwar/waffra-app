import 'dart:convert';
import 'legacy_snapshot_preflight.dart';

/// Read-only historical-account reconciliation. Inspect the exact original
/// source before writing any SQL table. No automatic account creation, no
/// ledger rewrite, and no silent assignment of old bank SMS receipts.
class WaffraAccountsMigrationPreview {
 const WaffraAccountsMigrationPreview({
  required this.sourceDigest,required this.historicalEntryCount,
  required this.cashIncomeMinor,required this.cashExpenseMinor,
  required this.goalWalletPaidMinor,required this.unassignedIds,
 });
 final String sourceDigest;
 final int historicalEntryCount,cashIncomeMinor,cashExpenseMinor;
 final int goalWalletPaidMinor;
 final List<String> unassignedIds;
 int get historicalNetCashMinor=>cashIncomeMinor-cashExpenseMinor;

 static WaffraAccountsMigrationPreview inspect({
  required Map<String,Object?> snapshot,
  Map<String,String> reviewedAccountForEntry=const {},
  Set<String> approvedAccountIds=const {},
 }) {
  final witness=WaffraLegacyPreflight.inspect(snapshot);
  if(!witness.canStage)throw StateError(
   'Historical finance cannot be safely reconciled.');
  final raw=snapshot['entries'];
  if(raw!=null && raw is! String)throw StateError('Historical ledger is not JSON.');
  final decoded=jsonDecode(raw as String? ?? '[]');
  if(decoded is! List || decoded.any((e)=>e is! Map)){
   throw StateError('Historical ledger is invalid.');
  }
  final ids=<String>{};
  var income=0,expense=0,wallet=0;
  for(final entry in decoded){
   final row=Map<String,Object?>.from(entry as Map);
   final id=row['id'],amount=row['amount'];
   if(id is! String || id.isEmpty || !ids.add(id) ||
      amount is! num || !amount.isFinite || amount<=0){
    throw StateError('Original entry is malformed or duplicated.');
   }
   final minor=(amount*100).round();
   if((amount*100-minor).abs()>0.000001)throw StateError(
    'Historical amount has unsupported sub-halalah precision.');
   final originalWallet=row['goalWalletPaidMinor'];
   final fromWallet=originalWallet is int?originalWallet:0;
   if(fromWallet<0||fromWallet>minor ||
       (fromWallet>0 && row['sourceType']!='goal_due')){
    throw StateError('Goal wallet allocation does not match historic entry.');
   }
   final amountCash=minor-fromWallet;
   if(row['income']==true){
    if(fromWallet!=0)throw StateError('Income cannot debit goal wallet.');
    income+=minor;
   }else if(row['income']==false){
    expense+=amountCash;
    wallet+=fromWallet;
   }else{
    throw StateError('Historical income/expense kind is invalid.');
   }
  }
  if(reviewedAccountForEntry.keys.any((id)=>!ids.contains(id)) ||
     reviewedAccountForEntry.values.any(
      (id)=>id.trim().isEmpty||!approvedAccountIds.contains(id))){
    throw StateError('Account mapping must reference existing verified IDs.');
  }
  return WaffraAccountsMigrationPreview(
   sourceDigest:witness.sourceSha256,
   historicalEntryCount:decoded.length,
   cashIncomeMinor:income,cashExpenseMinor:expense,
   goalWalletPaidMinor:wallet,
   unassignedIds:List.unmodifiable(ids
    .difference(reviewedAccountForEntry.keys.toSet()).toList()..sort()),
  );
 }
}
