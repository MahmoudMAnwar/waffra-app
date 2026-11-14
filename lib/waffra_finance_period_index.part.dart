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
   (_byId[_source[i].id]??=<int>[]).add(i);
  }
 }

 final List<MoneyEntry> _source;
 final Map<int,List<int>> _byMonth=<int,List<int>>{};
 final Map<int,List<int>> _byYear=<int,List<int>>{};
 final Map<String,List<int>> _byId=<String,List<int>>{};
 List<int>? _newestPositions;

 /// Stable newest-first read order, computed once per immutable ledger
 /// revision instead of sorting the entire history on every Home rebuild.
 /// Equal timestamps retain original source order. No writer/account guess.
 List<int> get _newestFirstPositions{
  final cached=_newestPositions;
  if(cached!=null)return cached;
  final positions=List<int>.generate(_source.length,(i)=>i);
  positions.sort((a,b){
   final byDate=_source[b].date.compareTo(_source[a].date);
   return byDate!=0?byDate:a.compareTo(b);
  });
  return _newestPositions=List<int>.unmodifiable(positions);
 }

 /// Exact verified-ID read projection. Null means all accounts;
 /// EMPTY verified ID scope means no assigned transactions.
 List<MoneyEntry> newestFirst({
  Set<String>? verifiedEntryIds,
  bool Function(MoneyEntry)? where,
 })=>_select(_newestFirstPositions.where((index){
  final row=_source[index];
  return (verifiedEntryIds==null||verifiedEntryIds.contains(row.id))&&
   (where==null||where(row));
 }));

 /// In-memory bounded page through the already sorted immutable index.
 /// This API does not claim SQLCipher database-level pagination.
 List<MoneyEntry> pageNewestFirst({
  Set<String>? verifiedEntryIds,
  bool Function(MoneyEntry)? where,
  required int offset,
  required int limit,
 }){
  if(offset<0||limit<0)throw RangeError('offset and limit must be nonnegative');
  if(limit==0)return const <MoneyEntry>[];
  var matched=0;
  final positions=<int>[];
  for(final index in _newestFirstPositions){
   final row=_source[index];
   if(verifiedEntryIds!=null&&!verifiedEntryIds.contains(row.id))continue;
   if(where!=null&&!where(row))continue;
   if(matched++<offset)continue;
   positions.add(index);
   if(positions.length==limit)break;
  }
  return _select(positions);
 }

 static int _monthKey(int year,int month)=>year*12+month-1;
 List<int> get years=>List<int>.unmodifiable(_byYear.keys);

 List<MoneyEntry> _select(Iterable<int> positions)=>
  List<MoneyEntry>.unmodifiable(positions.map((i)=>_source[i]));

 /// Account-specific Home and PDF reads use ONLY IDs witnessed by the
 /// SQLCipher account-link repository. Never auto-attach old unassigned rows.
 /// Keep source order (including imported historical rows) exactly intact.
 List<MoneyEntry> byIds(Set<String> verifiedEntryIds){
  if(verifiedEntryIds.isEmpty)return const <MoneyEntry>[];
  final positions=<int>[];
  for(final id in verifiedEntryIds){
   positions.addAll(_byId[id]??const <int>[]);
  }
  positions.sort();
  return _select(positions);
 }

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
