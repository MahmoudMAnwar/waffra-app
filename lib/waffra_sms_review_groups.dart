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
