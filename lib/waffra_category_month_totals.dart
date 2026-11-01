/// O(number of entries) once-per-build category summary for Waffra's
/// legacy finance UI. The finance writer is NOT changed here.
///
/// Legacy source records refer to category names, not immutable IDs. This
/// projection intentionally reproduces existing name-based report totals.
/// The planned stable-ID migration requires its own verified persistence PR.
class WaffraCategoryMonthTotals {
  const WaffraCategoryMonthTotals(this.byCategory,this.expenses);
  final Map<(bool,String),double> byCategory;
  final double expenses;

  double amountFor(bool income,String category)=>
      byCategory[(income,category)]??0;

  static WaffraCategoryMonthTotals build<T>(
    Iterable<T> entries,DateTime month,{
    required DateTime Function(T) date,
    required bool Function(T) income,
    required String Function(T) category,
    required double Function(T) amount,
  }) {
    final totals=<(bool,String),double>{};
    var expenseSum=0.0;
    for(final row in entries) {
      final rowDate=date(row);
      if(rowDate.year!=month.year||rowDate.month!=month.month)continue;
      final cash=amount(row);
      if(!cash.isFinite||cash<0) {
        throw StateError('Invalid verified category amount');
      }
      final isIncome=income(row);
      final key=(isIncome,category(row));
      totals[key]=(totals[key]??0)+cash;
      if(!isIncome)expenseSum+=cash;
    }
    return WaffraCategoryMonthTotals(
        Map<(bool,String),double>.unmodifiable(totals),expenseSum);
  }
}
