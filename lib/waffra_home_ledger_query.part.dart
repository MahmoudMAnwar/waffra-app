part of 'main.dart';

/// M941: display-only index lifetime separated from Home widget State.
/// The verified ledger remains owned by SQLCipher; no write is performed.
final class WaffraHomeLedgerReadCache {
 WaffraFinancePeriodIndex? _snapshot;
 WaffraFinancePeriodIndex index(List<MoneyEntry> source)=>
  _snapshot??=WaffraFinancePeriodIndex(source);
 void invalidate(){_snapshot=null;}
}

/// M941: the original dashboard search/date/amount/type/category predicate
/// is now a pure, testable query instead of being nested inside UI building.
/// Verified account row IDs are applied independently by the period index.
final class WaffraHomeTransactionFilter {
 WaffraHomeTransactionFilter({
  required String search,required this.typeFilter,
  required this.categoryFilter,this.dateRange,this.minAmount,this.maxAmount,
 }):search=search.trim();

 final String search,typeFilter,categoryFilter;
 final DateTimeRange? dateRange;
 final double? minAmount,maxAmount;

 bool acceptsType(MoneyEntry entry)=>
  typeFilter=='الكل'||
  (typeFilter=='الدخل'&&entry.income)||
  (typeFilter=='المصروفات'&&!entry.income)||
  (typeFilter=='الاستحقاقات'&&
   (entry.sourceType=='recurring'||entry.sourceType=='goal_due'));

 bool accepts(MoneyEntry entry)=>
  waffraSearchAny([entry.title,entry.category,waffraTr(entry.category)],search)&&
  (dateRange==null||
   (entry.date.isAfter(dateRange!.start.subtract(const Duration(days:1)))&&
    entry.date.isBefore(dateRange!.end.add(const Duration(days:1)))))&&
  (minAmount==null||entry.amount>=minAmount!)&&
  (maxAmount==null||entry.amount<=maxAmount!)&&
  acceptsType(entry)&&
  (categoryFilter=='الكل'||categoryFilter==entry.category);
}
