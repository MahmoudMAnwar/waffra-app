import 'waffra_sms_local_rules.dart';
import 'waffra_bank_sms_facts.dart';

class WaffraSmsRuleImpact {
 const WaffraSmsRuleImpact({
  required this.examined,required this.changed,required this.conflicts,
  required this.blockedExclusions,
 });
 final int examined,changed,conflicts,blockedExclusions;
}

/// Read-only impact estimate over up to 2000 CURRENT queued SMS. No rules are saved
/// and no original body, OTP, account or amount is retained in its result.
abstract final class WaffraSmsRuleSimulator {
 static String _suggestion(WaffraSmsRuleCandidateIndex index,
  Set<String> ruleIds,String body,String sender){
  final matched=index.candidates(body:body,sender:sender).where((rule)=>
   !rule.builtIn&&ruleIds.contains(rule.id)&&
   WaffraSmsLocalRules.matches(rule,body,sender:sender)).toList();
  final types=matched.map((r)=>r.resolvedKind).toSet();
  if(types.isEmpty)return 'review';
  if(types.length>1)return 'conflict';
  final categories=matched.map((r)=>r.category).where((x)=>x.isNotEmpty).toSet();
  return '${types.single}:${categories.length==1?categories.single:'unknown'}';
 }
 static WaffraSmsRuleImpact compare({
  required Iterable<MapEntry<String,String>> samples,
  required Iterable<WaffraSmsLocalRule> existing,
  required WaffraSmsLocalRule preview,
  String? replacingId,
  int maxMessages=2000,
 }){
  final prior=existing.toList(growable:false);
  final next=<WaffraSmsLocalRule>[
   ...prior.where((r)=>r.id!=replacingId),preview,
  ];
  // Build indexes once per preview, not for every message. Default system
  // rules are not counted as owner rules in before/after suggestions.
  final beforeIndex=WaffraSmsRuleCandidateIndex(prior);
  final afterIndex=WaffraSmsRuleCandidateIndex(next);
  final beforeIds=prior.map((r)=>r.id).toSet();
  final afterIds=next.map((r)=>r.id).toSet();
  var examined=0,changed=0,conflicts=0,blockedExclusions=0;
  for(final row in samples.take(maxMessages)){
   examined++;
   final before=_suggestion(beforeIndex,beforeIds,row.value,row.key);
   final after=_suggestion(afterIndex,afterIds,row.value,row.key);
   if(before!=after)changed++;
   if(after=='conflict')conflicts++;
   // Show where a new exclusion WOULD match text but the real SMS
   // safety resolver vetoes it (posted money, mixed OTP, conflict).
   // Simulation never calls native ACK or mutates financial records.
   if(preview.resolvedKind=='excluded'&&
      WaffraSmsLocalRules.matches(preview,row.value,sender:row.key)){
    final matched=WaffraSmsLocalRules.matchAllFourKinds(
      body:row.value,sender:row.key,custom:next,
      candidateIndex:afterIndex);
    final safe=WaffraSmsLocalRules.resolveSpecial(
      body:row.value,sender:row.key,
      bankKind:WaffraBankSmsFactsParser.parse(row.value).kind,
      custom:next,matchedRules:matched);
    if(safe?.resolvedKind!='excluded')blockedExclusions++;
   }
  }
  return WaffraSmsRuleImpact(
   examined:examined,changed:changed,conflicts:conflicts,
   blockedExclusions:blockedExclusions);
 }
}
