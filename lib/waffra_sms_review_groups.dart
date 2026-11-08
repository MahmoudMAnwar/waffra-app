/// Linear-time, case-insensitive sender grouping for large local SMS queues.
/// This is a presentation-only projection; it never mutates or acknowledges
/// the encrypted native queue, finance entries, sender exclusions or OTP data.
class WaffraSmsReviewGroups {
 WaffraSmsReviewGroups._(this.bySender,this.senders);

 final Map<String,List<Map<String,Object?>>> bySender;
 final List<String> senders;

 factory WaffraSmsReviewGroups.from(
  Iterable<Map<String,Object?>> messages,{
  required String unknownSender,
 }) {
  final bySender=<String,List<Map<String,Object?>>>{};
  final canonicalNames=<String,String>{};
  for(final message in messages){
   final raw=message['sender'] is String?
    (message['sender'] as String).trim():'';
   final name=raw.isEmpty?unknownSender:raw;
   final canonical=canonicalNames.putIfAbsent(
    name.toLowerCase(),()=>name);
   bySender.putIfAbsent(canonical,()=> <Map<String,Object?>>[]).add(message);
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
  return WaffraSmsReviewGroups._(bySender,senders);
 }
}
