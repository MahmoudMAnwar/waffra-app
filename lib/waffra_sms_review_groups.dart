/// Linear-time, case-insensitive sender grouping for large local SMS queues.
/// This is a presentation-only projection; it never mutates or acknowledges
/// the encrypted native queue, finance entries, sender exclusions or OTP data.
class WaffraSmsReviewGroups {
 WaffraSmsReviewGroups._(this.bySender,this.senders,this._ownersById);

 final Map<String,List<Map<String,Object?>>> bySender;
 final List<String> senders;
 // Presentation-only index: one native SMS ID can occur in more than one
 // group in malformed/legacy review snapshots; remove it from EVERY owner.
 final Map<String,Set<String>> _ownersById;

 /// Update one reviewed message without walking every sender on each tap.
 /// Call only after the original native pending queue confirms it is gone.
 bool removeReviewedId(String id){
  final owners=_ownersById.remove(id);
  if(owners==null)return false;
  for(final owner in owners){
   final rows=bySender[owner];
   if(rows==null)continue;
   rows.removeWhere((row)=>row['id']==id);
   if(rows.isEmpty){
    bySender.remove(owner);
    senders.remove(owner);
   }
  }
  return true;
 }

 factory WaffraSmsReviewGroups.from(
  Iterable<Map<String,Object?>> messages,{
  required String unknownSender,
 }) {
  final bySender=<String,List<Map<String,Object?>>>{};
  final canonicalNames=<String,String>{};
  final ownersById=<String,Set<String>>{};
  for(final message in messages){
   final raw=message['sender'] is String?
    (message['sender'] as String).trim():'';
   final name=raw.isEmpty?unknownSender:raw;
   final canonical=canonicalNames.putIfAbsent(
    name.toLowerCase(),()=>name);
   bySender.putIfAbsent(canonical,()=> <Map<String,Object?>>[]).add(message);
   final id=message['id'];
   if(id is String)(ownersById[id]??=<String>{}).add(canonical);
  }
  final senders=bySender.keys.toList()
   ..sort((a,b)=>a.toLowerCase().compareTo(b.toLowerCase()));
  for(final rows in bySender.values){
   rows.sort((a,b){
    final x=a['receivedAt'] is int?a['receivedAt'] as int:0;
    final y=b['receivedAt'] is int?b['receivedAt'] as int:0;
    return y.compareTo(x);
   });
  }
  return WaffraSmsReviewGroups._(bySender,senders,ownersById);
 }
}

/// Metadata-only receipt of an already-booked bank SMS operation.
class WaffraSmsCalendarBookedEvent {
 const WaffraSmsCalendarBookedEvent({
  required this.id,required this.date,required this.income,
 });
 final String id;
 final DateTime date;
 final bool income;
}

/// M984: an O(N) presentation-only index for an authenticated SMS inbox.
/// Dates use SMS *receivedAt*, not any unverified bank posting timestamp.
/// Confirmed recurring/goal-due entries are separate events and NEVER counted
/// as SMS. No raw SMS body, OTP, financial write or persistent state is used.
class WaffraSmsReviewCalendarIndex {
 WaffraSmsReviewCalendarIndex._(
  this._smsCount,this._dueCount,this._bookedCount,this._kinds,this._dayByMessageId);

 final Map<DateTime,int> _smsCount;
 final Map<DateTime,int> _dueCount;
 final Map<DateTime,int> _bookedCount;
 final Map<DateTime,List<String>> _kinds;
 final Map<String,DateTime> _dayByMessageId;

 static DateTime day(DateTime value)=>DateTime(value.year,value.month,value.day);
 static DateTime? receivedDay(Map<String,Object?> row){
  final receivedAt=row['receivedAt'];
  if(receivedAt is! int||receivedAt<=0)return null;
  try{
   return day(DateTime.fromMillisecondsSinceEpoch(receivedAt));
  }catch(_){return null;}
 }

 factory WaffraSmsReviewCalendarIndex.from(
  Iterable<Map<String,Object?>> messages,{
  Iterable<DateTime> paidDueDates=const <DateTime>[],
  Iterable<WaffraSmsCalendarBookedEvent> bookedBankEntries=
   const <WaffraSmsCalendarBookedEvent>[],
 }){
  final sms=<DateTime,int>{},due=<DateTime,int>{},booked=<DateTime,int>{};
  final colored=<DateTime,List<String>>{},identities=<String,DateTime>{};
  for(final row in messages){
   final id=row['id'];
   final when=receivedDay(row);
   // A malformed/legacy duplicate native ID cannot inflate the calendar.
   if(id is! String||id.isEmpty||when==null||identities.containsKey(id)){
    continue;
   }
   identities[id]=when;
   sms[when]=(sms[when]??0)+1;
   final local=row['local'];
   final suggestion=local is Map?local['kind']:null;
   final kind=const <String>{'income','expense','transfer','due'}
    .contains(suggestion)?suggestion as String:'uncertain';
   final dots=colored.putIfAbsent(when,()=>[]);
   if(dots.length<3)dots.add(kind);
  }
  for(final date in paidDueDates){
   final when=day(date);
   due[when]=(due[when]??0)+1;
  }
  // The booked ledger has unique financial IDs distinct from native pending SMS.
  // No message body, sender, notes, amount or finance authority enters index.
  final bookedIds=<String>{};
  for(final entry in bookedBankEntries){
   if(entry.id.isEmpty||!bookedIds.add(entry.id))continue;
   final when=day(entry.date);
   booked[when]=(booked[when]??0)+1;
   final dots=colored.putIfAbsent(when,()=>[]);
   if(dots.length<3)dots.add(entry.income?'income':'expense');
  }
  // Preserve one visible violet due marker in mixed days, and never show
  // more than three dots even when the real event count is much larger.
  for(final entry in due.entries){
   final dots=colored.putIfAbsent(entry.key,()=>[]);
   if(dots.length>=3){
    dots[2]='due';
   }else{
    for(var i=0;i<entry.value&&dots.length<3;i++)dots.add('due');
   }
  }
  return WaffraSmsReviewCalendarIndex._(
   Map<DateTime,int>.unmodifiable(sms),
   Map<DateTime,int>.unmodifiable(due),
   Map<DateTime,int>.unmodifiable(booked),
   Map<DateTime,List<String>>.unmodifiable({
    for(final e in colored.entries)
     e.key:List<String>.unmodifiable(e.value),
   }),
   Map<String,DateTime>.unmodifiable(identities));
 }

 int smsCount(DateTime date)=>_smsCount[day(date)]??0;
 int dueCount(DateTime date)=>_dueCount[day(date)]??0;
 int bookedCount(DateTime date)=>_bookedCount[day(date)]??0;
 int totalCount(DateTime date)=>smsCount(date)+bookedCount(date)+dueCount(date);
 List<String> dots(DateTime date)=>_kinds[day(date)]??const <String>[];
 bool matchesId(String id,DateTime date)=>_dayByMessageId[id]==day(date);
 bool hasDay(DateTime date)=>totalCount(date)>0;
}
