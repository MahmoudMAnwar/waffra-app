part of 'main.dart';

/// M684: one read-only index per hydrated finance-ledger revision.
///
/// The authenticated Home/Widget SQLCipher snapshot remains the sole source
/// of truth. This class only indexes MoneyEntry references for *display*;
/// it never generates account assignments, postings, balances or new IDs.
/// Callers invalidate the cached index on every ledger insert/edit/delete,
/// when loading/replacing a snapshot and after restore/reset.
class WaffraFinancePeriodIndex {
 WaffraFinancePeriodIndex(Iterable<MoneyEntry> source)
  : _source=List<MoneyEntry>.unmodifiable(source){
  for(var i=0;i<_source.length;i++){
   final date=_source[i].date;
   (_byMonth[_monthKey(date.year,date.month)]??=<int>[]).add(i);
   (_byYear[date.year]??=<int>[]).add(i);
  }
 }

 final List<MoneyEntry> _source;
 final Map<int,List<int>> _byMonth=<int,List<int>>{};
 final Map<int,List<int>> _byYear=<int,List<int>>{};

 static int _monthKey(int year,int month)=>year*12+month-1;
 List<int> get years=>List<int>.unmodifiable(_byYear.keys);

 List<MoneyEntry> _select(Iterable<int> positions)=>
  List<MoneyEntry>.unmodifiable(positions.map((i)=>_source[i]));

 /// A month-specific read only touches the requested monthly bucket.
 List<MoneyEntry> month(int year,int month){
  if(month<1||month>12)throw ArgumentError('Month must be 1..12.');
  return _select(_byMonth[_monthKey(year,month)]??const <int>[]);
 }

 /// Analytics annual view retains precisely the same historical entries.
 List<MoneyEntry> year(int year)=>
  _select(_byYear[year]??const <int>[]);

 /// Forecast's distinct months, preserving original ledger display order
 /// and preventing repeated month inputs from counting the same money twice.
 List<MoneyEntry> months(Iterable<DateTime> periods){
  final distinct=<int>{
   for(final date in periods)_monthKey(date.year,date.month),
  };
  final positions=<int>[];
  for(final key in distinct){
   positions.addAll(_byMonth[key]??const <int>[]);
  }
  positions.sort();
  return _select(positions);
 }

 /// Bound a Smart Analysis/date-range read to populated periods. A final
 /// timestamp comparison preserves exact boundary and future-date semantics.
 List<MoneyEntry> between(DateTime start,DateTime end,{
  bool startInclusive=true,bool endInclusive=false,
 }){
  if(start.isAfter(end))return const <MoneyEntry>[];
  final from=_monthKey(start.year,start.month);
  final until=_monthKey(end.year,end.month);
  final positions=<int>[];
  for(final group in _byMonth.entries){
   if(group.key>=from&&group.key<=until){
    positions.addAll(group.value);
   }
  }
  positions.sort();
  return _select(positions.where((index){
   final at=_source[index].date;
   return (startInclusive?!at.isBefore(start):at.isAfter(start))&&
    (endInclusive?!at.isAfter(end):at.isBefore(end));
  }));
 }

 /// Month-comparison balance reads only historical buckets before cutoff.
 /// This is a nonposting source projection, never an account cash authority.
 List<MoneyEntry> before(DateTime cutoff){
  final positions=<int>[];
  final last=_monthKey(cutoff.year,cutoff.month);
  for(final group in _byMonth.entries){
   if(group.key<=last)positions.addAll(group.value);
  }
  positions.sort();
  return _select(positions.where((index)=>
   _source[index].date.isBefore(cutoff)));
 }
}
