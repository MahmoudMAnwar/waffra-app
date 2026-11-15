import 'waffra_sms_local_rules.dart';

class WaffraSmsRuleImpact {
 const WaffraSmsRuleImpact({
  required this.examined,required this.changed,required this.conflicts,
 });
 final int examined,changed,conflicts;
}

/// Read-only impact estimate over explicit sample SMS. No rules are saved
/// and no original body, OTP, account or amount is retained in its result.
abstract final class WaffraSmsRuleSimulator {
 static String _suggestion(Iterable<WaffraSmsLocalRule> rules,
  String body,String sender){
  final matched=rules.where((rule)=>
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
  int maxMessages=100,
 }){
  final prior=existing.toList(growable:false);
  final next=<WaffraSmsLocalRule>[
   ...prior.where((r)=>r.id!=replacingId),preview,
  ];
  var examined=0,changed=0,conflicts=0;
  for(final row in samples.take(maxMessages)){
   examined++;
   final before=_suggestion(prior,row.value,row.key);
   final after=_suggestion(next,row.value,row.key);
   if(before!=after)changed++;
   if(after=='conflict')conflicts++;
  }
  return WaffraSmsRuleImpact(
   examined:examined,changed:changed,conflicts:conflicts);
 }
}
