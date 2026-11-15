import 'dart:convert';

import 'waffra_sms_local_rules.dart';

/// M991: same-session optimization ONLY, never a new SMS/financial authority.
/// The verified Android pending queue remains the authoritative source.
abstract final class WaffraSmsIncrementalRuleReview {
 static List<WaffraSmsLocalRule> changedRules(
  Iterable<WaffraSmsLocalRule> previous,
  Iterable<WaffraSmsLocalRule> current,
 ){
  final old=<String,WaffraSmsLocalRule>{
   for(final r in previous)r.id:r,
  };
  final next=<String,WaffraSmsLocalRule>{
   for(final r in current)r.id:r,
  };
  final changed=<WaffraSmsLocalRule>[];
  for(final id in <String>{...old.keys,...next.keys}){
   final before=old[id],after=next[id];
   if(before!=null&&after!=null&&
      jsonEncode(before.toJson())==jsonEncode(after.toJson()))continue;
   if(before!=null)changed.add(before);
   if(after!=null)changed.add(after);
  }
  return List<WaffraSmsLocalRule>.unmodifiable(changed);
 }

 /// Reassess if the new OR old version of a changed rule can match the SMS.
 /// Sender-only changes, removals, matchAll edits and category edits are
 /// therefore conservative: no false reuse for an affected pending message.
 static bool affected({
  required String body,required String sender,
  required Iterable<WaffraSmsLocalRule> changes,
 })=>changes.any((rule)=>
  WaffraSmsLocalRules.matches(rule,body,sender:sender));

 static bool canReuse({
  required Map<String,Object?> previous,
  required String currentId,
  required String currentSender,
  required String currentBodyHash,
  required String currentBody,
  required Iterable<WaffraSmsLocalRule> changed,
 }){
  if(currentId.isEmpty||previous['id']!=currentId||
     previous['sender']!=currentSender||
     previous['m991SourceHash']!=currentBodyHash||
     previous['m991Evaluated']!=true)return false;
  final oldLocal=previous['local'];
  // Native ACK/exclusion is *never* inherited. Re-evaluate each attempt.
  if(oldLocal is Map && oldLocal['kind']=='excluded')return false;
  return !affected(body:currentBody,sender:currentSender,changes:changed);
 }
}
