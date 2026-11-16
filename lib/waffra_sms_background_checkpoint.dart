/// M1020 / #737: select only candidates not yet durably attempted in the
/// owner-encrypted native SMS queue. This is a pure planner; it never posts
/// money, acknowledges an SMS or saves a checkpoint.
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Opaque version marker: no bank message, phone or rule contents stored
/// separately from the already owner-encrypted native SMS queue.
String waffraSmsRulesRevision(String owner,bool ready,
 List<Map<String,Object?>> rules)=>
 sha256.convert(utf8.encode(jsonEncode(<String,Object?>{
  'owner':owner,'ready':ready,'rules':rules,
 }))).toString();

final class WaffraSmsBackgroundCheckpoint {
 static WaffraSmsBackgroundSelection<Map<String,Object?>> select(
  List<Map<String,Object?>> pending,{int maxPerPass=25,String? currentRulesRevision}
 ){
  if(maxPerPass<=0){
   throw ArgumentError.value(maxPerPass,'maxPerPass','Must be positive');
  }
  final selected=<Map<String,Object?>>[];
  var total=0;
  for(final item in pending){
   if(item['backgroundAttempted']==true &&
      (currentRulesRevision==null ||
       item['backgroundRuleRevision']==currentRulesRevision))continue;
   total++;
   if(selected.length<maxPerPass)selected.add(item);
  }
  return WaffraSmsBackgroundSelection<Map<String,Object?>>(
   List.unmodifiable(selected),total,
  );
 }
 static int remainingAfter(int unattempted,int committedOrReviewed){
  if(unattempted<0||committedOrReviewed<0||
     committedOrReviewed>unattempted){
   throw ArgumentError('Invalid SMS background checkpoint counts');
  }
  return unattempted-committedOrReviewed;
 }
}

final class WaffraSmsBackgroundSelection<T>{
 const WaffraSmsBackgroundSelection(this.candidates,this.unattempted);
 final List<T> candidates;
 final int unattempted;
 int get remaining=>unattempted-candidates.length;
}
