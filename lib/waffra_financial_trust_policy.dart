/// M1000: read-only trust calculations. No database writer or auto-correction.
class WaffraTrustAccountResult {
 const WaffraTrustAccountResult({
  required this.id,required this.name,
  required this.actualMinor,required this.expectedMinor,
  required this.openingMinor,
 });
 final String id,name;
 final int actualMinor,expectedMinor,openingMinor;
 int get differenceMinor=>actualMinor-expectedMinor;
 bool get matches=>differenceMinor==0;
}
class WaffraTrustScan {
 const WaffraTrustScan({
  required this.accounts,required this.unassignedEntries,
  required this.unassignedNetMinor,required this.transferCount,
  required this.checkedAt,
 });
 final List<WaffraTrustAccountResult> accounts;
 final int unassignedEntries,unassignedNetMinor,transferCount;
 final DateTime checkedAt;
 bool get matches=>accounts.every((row)=>row.matches);
 int get totalMinor=>accounts.fold<int>(0,(v,e)=>v+e.actualMinor);
 int get differenceMinor=>accounts.fold<int>(0,(v,e)=>v+e.differenceMinor);
}

/// A due is never a posted transaction. These are projections ONLY.
class WaffraTrustDue {
 const WaffraTrustDue({
  required this.id,required this.accountId,required this.title,
  required this.due,required this.amountMinor,required this.income,
  this.paid=false,
 });
 final String id,accountId,title;
 final DateTime due;
 final int amountMinor;
 final bool income,paid;
}
class WaffraTrustDueCollision {
 const WaffraTrustDueCollision(this.firstId,this.secondId);
 final String firstId,secondId;
}
abstract final class WaffraTrustRecurringReview {
 static List<WaffraTrustDueCollision> possibleDuplicates(
  Iterable<WaffraTrustDue> source,
 ) {
  final seenIds=<String>{};
  final byFingerprint=<String,String>{};
  final collisions=<WaffraTrustDueCollision>[];
  for(final item in source) {
   if(item.id.trim().isEmpty||item.accountId.trim().isEmpty||
      item.amountMinor<=0)throw StateError('Invalid due proposal.');
   if(!seenIds.add(item.id)) {
    collisions.add(WaffraTrustDueCollision(item.id,item.id));
    continue;
   }
   if(item.paid)continue;
   // A shared day/amount isn't proof of double payment. Report only.
   final date=DateTime(item.due.year,item.due.month,item.due.day);
   final key=item.accountId+'|'+date.toIso8601String()+'|'+
      item.title.trim().toLowerCase()+'|'+item.amountMinor.toString()+
      '|'+item.income.toString();
   final other=byFingerprint.putIfAbsent(key,()=>item.id);
   if(other!=item.id)collisions.add(
    WaffraTrustDueCollision(other,item.id));
  }
  return List.unmodifiable(collisions);
 }
}
class WaffraTrustCashflowPoint {
 const WaffraTrustCashflowPoint(this.day,this.expectedMinor);
 final DateTime day;
 final int expectedMinor;
}
class WaffraTrustCashflowForecast {
 const WaffraTrustCashflowForecast(this.startMinor,this.points);
 final int startMinor;
 final List<WaffraTrustCashflowPoint> points;
 int get endingMinor=>points.isEmpty?startMinor:points.last.expectedMinor;
}

/// Never confuses a scheduled item with an actual cash movement.
abstract final class WaffraTrustCashflow {
 static WaffraTrustCashflowForecast project({
  required int verifiedCurrentMinor,
  required DateTime today,required DateTime through,
  required Iterable<WaffraTrustDue> dues,
  String? accountId,
 }) {
  if(through.isBefore(today)||through.difference(today).inDays>366) {
   throw ArgumentError('Forecast horizon must be between 0 and 366 days.');
  }
  final start=DateTime(today.year,today.month,today.day);
  final end=DateTime(through.year,through.month,through.day);
  final pending=<DateTime,int>{};
  for(final row in dues) {
   if(row.amountMinor<=0||row.id.isEmpty||row.accountId.isEmpty) {
    throw StateError('Unsafe upcoming payment.');
   }
   if(row.paid||accountId!=null&&row.accountId!=accountId)continue;
   final scheduled=DateTime(row.due.year,row.due.month,row.due.day);
   // An unpaid overdue bill affects available future cash immediately;
   // do not pretend that it vanished because its due date passed.
   final day=scheduled.isBefore(start)?start:scheduled;
   if(day.isAfter(end))continue;
   pending[day]=(pending[day]??0)+(row.income
    ?row.amountMinor:-row.amountMinor);
  }
  var balance=verifiedCurrentMinor;
  final sorted=pending.keys.toList()..sort();
  final points=<WaffraTrustCashflowPoint>[];
  for(final day in sorted) {
   balance+=pending[day]!;
   points.add(WaffraTrustCashflowPoint(day,balance));
  }
  return WaffraTrustCashflowForecast(
   verifiedCurrentMinor,List.unmodifiable(points));
 }
}
/// A prospective change record is prepared before a verified writer commits.
/// This class must NEVER be treated as durable history or proof of a commit.
class WaffraTrustChangeProposal {
 const WaffraTrustChangeProposal({
  required this.recordId,required this.field,
  required this.before,required this.after,
 });
 final String recordId,field,before,after;
 bool get changed=>before!=after;
}
