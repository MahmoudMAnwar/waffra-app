/// Read-only per-account budget allocations in integer Saudi halalas.
///
/// A shared budget is not automatically multiplied by the number of
/// accounts. Only explicit assigned caps are summed for the All view.
class WaffraAccountMonthlyCap {
 const WaffraAccountMonthlyCap({
  required this.budgetId,required this.accountId,required this.capMinor,
 });
 final String budgetId,accountId;
 final int capMinor;
}

class WaffraAccountMonthlySpend {
 const WaffraAccountMonthlySpend({
  required this.budgetId,required this.accountId,
  required this.amountMinor,required this.monthIso,
 });
 final String budgetId,accountId,monthIso;
 final int amountMinor;
}

class WaffraAccountMonthlyBudget {
 const WaffraAccountMonthlyBudget({
  required this.capMinor,required this.spentMinor,
 });
 final int capMinor,spentMinor;
 int get remainingMinor=>capMinor-spentMinor;
}

/// This is a pure projection: it never creates a budget, writes a ledger
/// row or guesses which existing shared budget belongs to which account.
abstract final class WaffraAccountMonthlyBudgetPolicy {
 static WaffraAccountMonthlyBudget calculate({
  required Iterable<WaffraAccountMonthlyCap> assignedCaps,
  required Iterable<WaffraAccountMonthlySpend> spending,
  required String monthIso,
  String? selectedAccountId,
 }){
  if(!RegExp(r'^[0-9]{4}-(0[1-9]|1[0-2])$').hasMatch(monthIso)){
   throw ArgumentError('Invalid budget month.');
  }
  if(selectedAccountId!=null&&selectedAccountId.trim().isEmpty){
   throw ArgumentError('Invalid selected account.');
  }
  final unique=<String>{};
  final caps=<String,int>{};
  var limit=0,spent=0;
  for(final allocation in assignedCaps){
   if(allocation.budgetId.trim().isEmpty||allocation.accountId.trim().isEmpty||
      allocation.capMinor<0){
    throw ArgumentError('Invalid explicit account budget allocation.');
   }
   final key='${allocation.budgetId}|${allocation.accountId}';
   if(!unique.add(key))throw StateError('Account budget allocation was duplicated.');
   caps[key]=allocation.capMinor;
   if(selectedAccountId==null||selectedAccountId==allocation.accountId){
    limit+=allocation.capMinor;
   }
  }
  for(final entry in spending){
   if(entry.monthIso!=monthIso)continue;
   if(entry.amountMinor<=0)throw StateError('Invalid account budget expense.');
   final key='${entry.budgetId}|${entry.accountId}';
   if(!caps.containsKey(key))continue; // Never assign an unlinked expense.
   if(selectedAccountId==null||selectedAccountId==entry.accountId){
    spent+=entry.amountMinor;
   }
  }
  return WaffraAccountMonthlyBudget(capMinor:limit,spentMinor:spent);
 }
}
