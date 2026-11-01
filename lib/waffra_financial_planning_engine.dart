/// M342: pure, read-only financial planning. No legacy DB writer, FX,
/// cloud sync, or SQLCipher production changes. All amounts are SAR halalas.
enum GoalMoveKind { fund, withdraw, transfer }
class GoalMove {
  const GoalMove(this.id,this.kind,this.amountMinor,{this.from,this.to});
  final String id;
  final GoalMoveKind kind;
  final int amountMinor;
  final String? from,to;
}
class GoalBalances {
  const GoalBalances(this.spendableMinor,this.goalsMinor);
  final int spendableMinor;
  final Map<String,int> goalsMinor;
  int get reservedMinor=>goalsMinor.values.fold(0,(a,b)=>a+b);
  int get totalMinor=>spendableMinor+reservedMinor;
}
/// Existing goal.saved balances are NOT replayable events; use only confirmed
/// opening balances. Internal allocations never count as an expense.
abstract final class GoalWalletProjector {
  static GoalBalances replay(int openingSpendable,Map<String,int> openingGoals,
      Iterable<GoalMove> movements) {
    if(openingSpendable<0||openingGoals.keys.any((k)=>k.isEmpty)||
       openingGoals.values.any((v)=>v<0))throw StateError('invalid opening');
    var spendable=openingSpendable;
    final goals=Map<String,int>.of(openingGoals);
    final original=spendable+goals.values.fold<int>(0,(a,b)=>a+b);
    final ids=<String>{};
    for(final m in movements) {
      if(m.id.isEmpty||!ids.add(m.id)||m.amountMinor<=0) {
        throw StateError('duplicate or invalid movement');
      }
      final n=m.amountMinor;
      switch(m.kind) {
        case GoalMoveKind.fund:
          if(m.from!=null||m.to==null||!goals.containsKey(m.to)||
             spendable<n)throw StateError('invalid goal funding');
          spendable-=n; goals[m.to!]=goals[m.to!]!+n;
          break;
        case GoalMoveKind.withdraw:
          if(m.from==null||m.to!=null||!goals.containsKey(m.from)||
             goals[m.from]!<n)throw StateError('invalid withdrawal');
          goals[m.from!]=goals[m.from!]!-n;spendable+=n;
          break;
        case GoalMoveKind.transfer:
          if(m.from==null||m.to==null||m.from==m.to||
             !goals.containsKey(m.from)||!goals.containsKey(m.to)||
             goals[m.from]!<n)throw StateError('invalid goal transfer');
          goals[m.from!]=goals[m.from!]!-n;
          goals[m.to!]=goals[m.to!]!+n;
          break;
      }
    }
    final view=GoalBalances(spendable,Map.unmodifiable(goals));
    if(view.totalMinor!=original)throw StateError('money conservation');
    return view;
  }
}
class NamedBudget {
  const NamedBudget(this.id,this.name,this.categoryId,this.limitMinor,
      this.start,this.endExclusive);
  final String id,name,categoryId;
  final int limitMinor;
  final DateTime start,endExclusive;
}
class PostedExpense {
  const PostedExpense(this.id,this.categoryId,this.amountMinor,this.date,
      {this.confirmed=true});
  final String id,categoryId;
  final int amountMinor;
  final DateTime date;
  final bool confirmed;
}
class BudgetAllocation {
  const BudgetAllocation(this.expenseId,this.budgetId,this.amountMinor,
    {this.crossCategoryApproved=false});
  final String expenseId,budgetId;
  final int amountMinor;
  /// A user may explicitly choose a budget outside the inferred category.
  /// Only that explicit confirmation can override category suggestions.
  final bool crossCategoryApproved;
}
class BudgetPosition {
  const BudgetPosition(this.limitMinor,this.usedMinor);
  final int limitMinor,usedMinor;
  int get remainingMinor=>limitMinor-usedMinor;
  int get alertPercent=>usedMinor>=limitMinor?100:
    usedMinor*100>=limitMinor*80?80:
    usedMinor*100>=limitMinor*50?50:0;
}
class BudgetProjection {
  const BudgetProjection(this.positions,this.unassigned);
  final Map<String,BudgetPosition> positions;
  /// Unallocated amount per confirmed expense, including partial links.
  final Map<String,int> unassigned;
}
/// Stable IDs survive renames. No inferred budget links are ever saved.
abstract final class NamedBudgetProjector {
 static BudgetProjection review(Iterable<NamedBudget> budgets,
     Iterable<PostedExpense> expenses,Iterable<BudgetAllocation> links) {
  final b=<String,NamedBudget>{};
  for(final row in budgets) {
    if(row.id.isEmpty||row.name.trim().isEmpty||row.categoryId.isEmpty||
       row.limitMinor<=0||!row.start.isBefore(row.endExclusive)||
       b.containsKey(row.id))throw StateError('invalid budget');
    b[row.id]=row;
  }
  final e=<String,PostedExpense>{};
  for(final row in expenses) {
    if(row.id.isEmpty||row.categoryId.isEmpty||row.amountMinor<=0||
       e.containsKey(row.id))throw StateError('invalid expense');
    e[row.id]=row;
  }
  final used=<String,int>{},allocated=<String,int>{},pairs=<String>{};
  for(final link in links) {
    final expense=e[link.expenseId],budget=b[link.budgetId];
    if(expense==null||budget==null||!expense.confirmed||
       link.amountMinor<=0||
       !pairs.add(link.expenseId+'|'+link.budgetId)||
       (expense.categoryId!=budget.categoryId&&
          !link.crossCategoryApproved)||
       expense.date.isBefore(budget.start)||
       !expense.date.isBefore(budget.endExclusive)||
       (allocated[expense.id]??0)+link.amountMinor>expense.amountMinor) {
      throw StateError('invalid/overallocated budget link');
    }
    allocated[expense.id]=(allocated[expense.id]??0)+link.amountMinor;
    used[budget.id]=(used[budget.id]??0)+link.amountMinor;
  }
  return BudgetProjection(
   Map.unmodifiable({for(final row in b.values)
     row.id:BudgetPosition(row.limitMinor,used[row.id]??0)}),
   Map.unmodifiable({for(final row in e.values)
     if(row.confirmed&&(allocated[row.id]??0)<row.amountMinor)
       row.id:row.amountMinor-(allocated[row.id]??0)}));
 }
}
enum RecurringFrequency { weekly, monthly, yearly }
class RecurringPlan {
 const RecurringPlan(this.id,this.firstDue,this.frequency,
    this.amountMinor,this.categoryId,{this.merchantKey});
 final String id,categoryId;
 final DateTime firstDue;
 final RecurringFrequency frequency;
 final int amountMinor;
 final String? merchantKey;
}
class BankPaymentEvidence {
 const BankPaymentEvidence(this.id,this.date,this.amountMinor,
     this.categoryId,{this.merchantKey,required this.confirmed});
 final String id,categoryId;
 final DateTime date;
 final int amountMinor;
 final String? merchantKey;
 final bool confirmed;
}
/// A match is a *suggestion* only, never a second ledger write or a paid flag.
abstract final class RecurringPaymentReview {
 static DateTime nextDue(RecurringPlan plan,DateTime today) {
  if(plan.id.isEmpty||plan.categoryId.isEmpty||plan.amountMinor<=0) {
    throw StateError('invalid recurring plan');
  }
  final start=DateTime(plan.firstDue.year,plan.firstDue.month,plan.firstDue.day);
  final now=DateTime(today.year,today.month,today.day);
  switch(plan.frequency) {
   case RecurringFrequency.weekly:
    if(!start.isBefore(now))return start;
    final elapsed=now.difference(start).inDays;
    return start.add(Duration(days:((elapsed+6)~/7)*7));
   case RecurringFrequency.monthly:
    final threshold=now.isAfter(start)?now:start;
    DateTime due(int year,int month) {
      final last=DateTime(year,month+1,0).day;
      return DateTime(year,month,start.day>last?last:start.day);
    }
    var result=due(threshold.year,threshold.month);
    if(result.isBefore(threshold))result=due(threshold.year,threshold.month+1);
    return result;
   case RecurringFrequency.yearly:
    final threshold=now.isAfter(start)?now:start;
    DateTime due(int year) {
      final last=DateTime(year,start.month+1,0).day;
      return DateTime(year,start.month,start.day>last?last:start.day);
    }
    var result=due(threshold.year);
    if(result.isBefore(threshold))result=due(threshold.year+1);
    return result;
  }
 }
 static bool matches(RecurringPlan plan,BankPaymentEvidence payment,
      {required DateTime expectedDue,int toleranceDays=3,
       int amountToleranceMinor=0}) {
  if(!payment.confirmed||payment.id.isEmpty||toleranceDays<0||
      amountToleranceMinor<0||plan.amountMinor<=0||
      payment.amountMinor<=0||plan.categoryId!=payment.categoryId||
      (plan.amountMinor-payment.amountMinor).abs()>amountToleranceMinor) {
    return false;
  }
  // Identical sums without a known merchant do not prove identical charges.
  final merchant=plan.merchantKey?.trim().toLowerCase();
  if(merchant==null||merchant.isEmpty||
     merchant!=payment.merchantKey?.trim().toLowerCase())return false;
  final due=DateTime(expectedDue.year,expectedDue.month,expectedDue.day);
  final paid=DateTime(payment.date.year,payment.date.month,payment.date.day);
  return due.difference(paid).inDays.abs()<=toleranceDays;
 }
}


class BudgetRemovalPreview {
 const BudgetRemovalPreview(this.remainingBudgets,this.remainingLinks,
     this.recalculated);
 final List<NamedBudget> remainingBudgets;
 final List<BudgetAllocation> remainingLinks;
 final BudgetProjection recalculated;
}

/// Explicitly previews unlinked historical expenses when a budget is created,
/// and detaches links safely if a budget is removed. Neither method writes.
abstract final class BudgetChangeReview {
 static Map<String,List<String>> suggestUnlinked(
    Iterable<NamedBudget> budgets,Iterable<PostedExpense> expenses,
    Iterable<BudgetAllocation> existingLinks) {
  final allBudgets=budgets.toList(growable:false);
  final allExpenses=expenses.toList(growable:false);
  final allLinks=existingLinks.toList(growable:false);
  final projection=NamedBudgetProjector.review(
    allBudgets,allExpenses,allLinks);
  return Map.unmodifiable({
    for(final row in allExpenses)
      if(projection.unassigned.containsKey(row.id))
        row.id:List<String>.unmodifiable([
          for(final budget in allBudgets)
            if(budget.categoryId==row.categoryId &&
               !row.date.isBefore(budget.start) &&
               row.date.isBefore(budget.endExclusive) &&
               !allLinks.any((link)=>link.expenseId==row.id &&
                                      link.budgetId==budget.id))
              budget.id,
        ]),
  });
 }
 static BudgetRemovalPreview deleteBudget(
   String budgetId,Iterable<NamedBudget> budgets,
   Iterable<PostedExpense> expenses,Iterable<BudgetAllocation> links) {
  final oldBudgets=budgets.toList(growable:false);
  final source=expenses.toList(growable:false);
  final oldLinks=links.toList(growable:false);
  NamedBudgetProjector.review(oldBudgets,source,oldLinks);
  if(!oldBudgets.any((budget)=>budget.id==budgetId)) {
    throw StateError('Budget to remove does not exist');
  }
  final remainingBudgets=List<NamedBudget>.unmodifiable(
      oldBudgets.where((row)=>row.id!=budgetId));
  final remainingLinks=List<BudgetAllocation>.unmodifiable(
      oldLinks.where((row)=>row.budgetId!=budgetId));
  final refreshed=NamedBudgetProjector.review(
      remainingBudgets,source,remainingLinks);
  return BudgetRemovalPreview(remainingBudgets,remainingLinks,refreshed);
 }
}


class RecurringDueObligation {
 const RecurringDueObligation(this.scheduleId,this.dueDate,{
  this.alreadyPaid=false});
 final String scheduleId;
 final DateTime dueDate;
 final bool alreadyPaid;
 String get occurrenceKey => scheduleId+'@'+
   dueDate.year.toString().padLeft(4,'0')+'-'+
   dueDate.month.toString().padLeft(2,'0')+'-'+
   dueDate.day.toString().padLeft(2,'0');
}
class RecurringBatchReview {
 const RecurringBatchReview(this.uniqueSuggestions,this.ambiguousOccurrences,
     this.unmatchedPaymentIds);
 /// A suggestion is not payment confirmation and never writes a transaction.
 final Map<String,String> uniqueSuggestions;
 final Set<String> ambiguousOccurrences;
 final Set<String> unmatchedPaymentIds;
}

/// An incoming bank row can match several standing orders of the same
/// amount, or several bank rows may match one standing order. In either
/// case we abstain rather than automatically marking one obligation paid.
abstract final class RecurringBatchMatcher {
 static RecurringBatchReview review({
  required Iterable<RecurringPlan> plans,
  required Iterable<RecurringDueObligation> dues,
  required Iterable<BankPaymentEvidence> payments,
 }) {
  final planById=<String,RecurringPlan>{};
  for(final plan in plans) {
   if(plan.id.isEmpty||planById.containsKey(plan.id)) {
    throw StateError('Invalid or duplicate recurring schedule');
   }
   planById[plan.id]=plan;
  }
  final occurrences=<String,RecurringDueObligation>{};
  for(final due in dues) {
   final plan=planById[due.scheduleId];
   if(plan==null||occurrences.containsKey(due.occurrenceKey)) {
    throw StateError('Unknown or duplicated recurring occurrence');
   }
   final expected=RecurringPaymentReview.nextDue(plan,due.dueDate);
   final requested=DateTime(due.dueDate.year,due.dueDate.month,
     due.dueDate.day);
   // A fake due date must not make an unrelated bank payment look like a
   // settled scheduled charge. Explicit postponements need their own
   // reviewed occurrence provenance before this matching API is used.
   if(expected!=requested) {
    throw StateError('Unverified recurring due occurrence');
   }
   occurrences[due.occurrenceKey]=due;
  }
  final paymentById=<String,BankPaymentEvidence>{};
  for(final payment in payments) {
   if(payment.id.isEmpty||paymentById.containsKey(payment.id)) {
    throw StateError('Unknown or duplicate bank payment ID');
   }
   paymentById[payment.id]=payment;
  }
  final candidates=<String,List<String>>{};
  final reverse=<String,int>{};
  for(final due in occurrences.values) {
   if(due.alreadyPaid)continue;
   final plan=planById[due.scheduleId]!;
   final matches=<String>[];
   for(final payment in paymentById.values) {
    if(RecurringPaymentReview.matches(plan,payment,
       expectedDue:due.dueDate)) {
     matches.add(payment.id);
     reverse[payment.id]=(reverse[payment.id]??0)+1;
    }
   }
   candidates[due.occurrenceKey]=matches;
  }
  final accepted=<String,String>{},ambiguous=<String>{};
  for(final candidate in candidates.entries) {
   if(candidate.value.isEmpty)continue;
   if(candidate.value.length==1&&
      reverse[candidate.value.single]==1) {
    accepted[candidate.key]=candidate.value.single;
   }else{
    ambiguous.add(candidate.key);
   }
  }
  return RecurringBatchReview(Map.unmodifiable(accepted),
    Set.unmodifiable(ambiguous),
    Set.unmodifiable(paymentById.keys.toSet().difference(
      accepted.values.toSet())));
 }
}


class GoalAmountEvidence {
 const GoalAmountEvidence(this.id,this.targetMinor,this.savedMinor);
 final String id;
 final int targetMinor,savedMinor;
}
class GoalWalletHealthReport {
 const GoalWalletHealthReport(this.netLedgerMinor,this.reservedMinor,
    this.availableMinor,this.issues);
 final int netLedgerMinor,reservedMinor,availableMinor;
 /// Machine-readable warnings. No repairs or writes are performed.
 final List<String> issues;
 bool get reconciled => issues.isEmpty;
}
/// Reconcile old aggregate SavingGoal.saved snapshots conservatively.
/// Legacy saves have no contribution event history: never fabricate an
/// automatic movement from these scalar values or rewrite the cash ledger.
/// Negative cash after earmarking is flagged, never silently clamped to zero.
abstract final class GoalWalletHealthAudit {
 static GoalWalletHealthReport inspect(int verifiedNetLedgerMinor,
     Iterable<GoalAmountEvidence> goals) {
  final issues=<String>[];
  final ids=<String>{};
  var reserved=0;
  for(final goal in goals) {
   if(goal.id.trim().isEmpty||!ids.add(goal.id)) {
    issues.add('duplicate_or_missing_goal_id');
   }
   if(goal.targetMinor<=0||goal.savedMinor<0) {
    issues.add('invalid_goal_amount');
    continue;
   }
   // Saving beyond the original target may be intentional; it must not
   // silently result in disappearing or truncated savings.
   reserved+=goal.savedMinor;
  }
  final available=verifiedNetLedgerMinor-reserved;
  if(available<0)issues.add('goals_exceed_spendable_ledger');
  return GoalWalletHealthReport(verifiedNetLedgerMinor,reserved,available,
      List<String>.unmodifiable(issues));
 }
}
