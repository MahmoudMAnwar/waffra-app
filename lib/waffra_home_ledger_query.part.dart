part of 'main.dart';

/// M941: display-only index lifetime separated from Home widget State.
/// The verified ledger remains owned by SQLCipher; no write is performed.
final class WaffraHomeLedgerReadCache {
 WaffraFinancePeriodIndex? _snapshot;
 List<MoneyEntry>? _scopedMonthSource;
 Set<String>? _scopedMonthIds;
 List<MoneyEntry>? _scopedMonthResult;

 /// A verified finance ID-set is immutable for one source witness.
 /// A different ID-set object or month never shares an account filter.
 List<MoneyEntry> scopedMonth(
   List<MoneyEntry> monthRows,Set<String> verifiedEntryIds){
  final cached=_scopedMonthResult;
  if(cached!=null&&identical(_scopedMonthSource,monthRows)&&
      identical(_scopedMonthIds,verifiedEntryIds))return cached;
  final filtered=List<MoneyEntry>.unmodifiable(
    monthRows.where((e)=>verifiedEntryIds.contains(e.id)));
  _scopedMonthSource=monthRows;
  _scopedMonthIds=verifiedEntryIds;
  return _scopedMonthResult=filtered;
 }
 WaffraFinancePeriodIndex index(List<MoneyEntry> source)=>
  _snapshot??=WaffraFinancePeriodIndex(source);
 // M944: only a bounded number of cards may be built during a single Home
 // frame, even when the user has expanded a 10,000-row timeline.
 static const int expandedPageSize=50;
 int _expandedLimit=expandedPageSize;
 int get expandedLimit=>_expandedLimit;
 bool revealNext(int total){
  if(total<0)throw RangeError.value(total,'total');
  if(_expandedLimit>=total)return false;
  _expandedLimit=(_expandedLimit+expandedPageSize)<total
   ?_expandedLimit+expandedPageSize:total;
  return true;
 }
 void resetExpanded(){_expandedLimit=expandedPageSize;}
 void invalidate(){
  _snapshot=null;
  _scopedMonthSource=null;
  _scopedMonthIds=null;
  _scopedMonthResult=null;
  resetExpanded();
 }
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

 // DateRangePicker selects calendar DAYS, not a 24-hour window before
 // the start timestamp. Never include yesterday's bank transaction.
 bool acceptsCalendarDate(DateTime when){
  final period=dateRange;
  if(period==null)return true;
  final day=DateTime(when.year,when.month,when.day);
  final first=DateTime(period.start.year,period.start.month,period.start.day);
  final last=DateTime(period.end.year,period.end.month,period.end.day);
  return !day.isBefore(first)&&!day.isAfter(last);
 }
 bool accepts(MoneyEntry entry)=>
  waffraSearchAny([entry.title,entry.category,waffraTr(entry.category)],search)&&
  acceptsCalendarDate(entry.date)&&
  (minAmount==null||entry.amount>=minAmount!)&&
  (maxAmount==null||entry.amount<=maxAmount!)&&
  acceptsType(entry)&&
  (categoryFilter=='الكل'||categoryFilter==entry.category);
}
