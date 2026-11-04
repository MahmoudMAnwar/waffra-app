/// One confirmed goal expense reduces its saved earmark and the ledger once.
/// The remaining expense, if any, comes from spendable cash. Merely reaching
/// a due date NEVER modifies either balance.
class WaffraGoalDueAllocation {
 const WaffraGoalDueAllocation._({
  required this.amountMinor,
  required this.fromGoalMinor,
  required this.fromCurrentMinor,
  required this.remainingGoalMinor,
 });
 final int amountMinor,fromGoalMinor,fromCurrentMinor,remainingGoalMinor;

 double get amount=>amountMinor/100;
 double get fromGoalWallet=>fromGoalMinor/100;
 double get fromCurrentBalance=>fromCurrentMinor/100;
 double get remainingGoalSavings=>remainingGoalMinor/100;

 static int _minor(double value,{required bool positive}) {
  if(!value.isFinite || (positive?value<=0:value<0) ||
    value>100000000000) {
   throw ArgumentError.value(value,'money','Invalid goal money');
  }
  final rounded=(value*100).round();
  if((value*100-rounded).abs()>0.00001) {
   throw ArgumentError.value(value,'money','Excess halala precision');
  }
  return rounded;
 }

 static WaffraGoalDueAllocation allocate({
  required double dueAmount,required double goalSaved,
 }) {
  final due=_minor(dueAmount,positive:true);
  final reserved=_minor(goalSaved,positive:false);
  final fromGoal=reserved<due?reserved:due;
  return WaffraGoalDueAllocation._(
   amountMinor:due,fromGoalMinor:fromGoal,
   fromCurrentMinor:due-fromGoal,remainingGoalMinor:reserved-fromGoal);
 }
}
