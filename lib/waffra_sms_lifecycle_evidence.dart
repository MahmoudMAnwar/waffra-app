import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'waffra_bank_sms_facts.dart';
import 'waffra_sms_account_learning.dart';
import 'waffra_sms_structured_bank_context.dart';

enum WaffraSmsLifecycleStage {
 pending,posted,failed,reversed,refunded,uncertain
}
enum WaffraSmsRelatedEvent {
 none,possibleDuplicate,possibleSettlement,possibleReversal,relatedNeedsReview
}

/// Safe read-only relation evidence; never authorizes a bank ledger mutation.
/// A sender + reference + masked account + exact SAR amount must ALL agree.
class WaffraSmsLifecycleEvidence {
 const WaffraSmsLifecycleEvidence({
  required this.stage,required this.relationKey,
 });
 final WaffraSmsLifecycleStage stage;
 final String? relationKey;

 static WaffraSmsLifecycleEvidence inspect(String body,{
  required String sender,WaffraSmsStructuredBankContext? context,
 }){
  final structured=context??WaffraSmsStructuredBankContext.parse(
   body,sender:sender);
  final facts=structured.facts;
  final reversed=RegExp(
   r'\b(?:reversed|reversal|chargeback|voided)\b|'
   r'عكس\s+العملي[ةه]|تم\s+(?:الغاء|إلغاء)\s+العملي[ةه]',
   caseSensitive:false).hasMatch(body);
  final refunded=RegExp(
   r'\b(?:refund\s+(?:received|processed)|refunded)\b|'
   r'تم\s+(?:استرداد|رد)\s+المبلغ|استرداد\s+مبلغ',
   caseSensitive:false).hasMatch(body);
  final failed=RegExp(
   r'\b(?:declined|rejected|failed|unsuccessful)\b|'
   r'مرفوض[ةه]?|فشلت|غير\s+ناجح[ةه]?',
   caseSensitive:false).hasMatch(body);
  final pending=RegExp(
   r'\b(?:pending|preauth|authorization\s+hold)\b|'
   r'معلق[ةه]?|قيد\s+المعالج[ةه]',
   caseSensitive:false).hasMatch(body);
  final stage=reversed?WaffraSmsLifecycleStage.reversed:
   refunded?WaffraSmsLifecycleStage.refunded:
   failed?WaffraSmsLifecycleStage.failed:
   pending?WaffraSmsLifecycleStage.pending:
   !facts.pending&&structured.principalSar!=null?
    WaffraSmsLifecycleStage.posted:
    WaffraSmsLifecycleStage.uncertain;
  final provider=WaffraSmsAccountLearning.bankGroup(sender);
  final ref=facts.reference?.trim().toUpperCase();
  // Prevent a reference reused by another sender from joining two rows.
  // Do not link account-less notices or balances to money events.
  String? key;
  if(provider!=null&&ref!=null&&ref.length>=5&&!structured.composite){
   final source=facts.sourceSuffix,dest=facts.destinationSuffix;
   final suffix=source!=null&&dest!=null?'$source:$dest':
    source??dest;
   // Reuse the amount extracted by the structured parser, even if pending.
   // Lifecycle linking remains advisory and never authorizes money.
   final money=structured.referenceAmountSar;
   if(suffix!=null&&money!=null&&money>0){
    final scaled=money*100;
    final minor=scaled.round();
    if((scaled-minor).abs()<0.000001){
     key='${WaffraSmsAccountLearning.senderKey(sender)}|$ref|$suffix|$minor';
    }
   }
  }
  return WaffraSmsLifecycleEvidence(stage:stage,relationKey:key);
 }
}

/// Per-batch in-memory exact-evidence index. Its output is *advisory only*:
/// it never removes an SMS, marks a ledger transaction, or confirms an ACK.
class WaffraSmsRelatedEventIndex {
 WaffraSmsRelatedEventIndex({
  Iterable<Map<String,Object?>> prior=const [],
 }){
  for(final row in prior){
   final key=row['key'],source=row['source'];
   final stage=row['stage'],seenAt=row['seenAt'];
   if(key is! String||source is! String||stage is! String||
      seenAt is! int||!RegExp(r'^[a-f0-9]{64}$').hasMatch(key)||
      !RegExp(r'^[a-f0-9]{64}$').hasMatch(source))continue;
   final parsed=WaffraSmsLifecycleStage.values.where(
    (value)=>value.name==stage);
   if(parsed.length!=1)continue;
   _prior[key]=WaffraSmsLifecycleEvidence(
    stage:parsed.single,relationKey:null);
   _nativeSources[key]=source;
   _lastSeen[key]=seenAt;
  }
 }
 static String digest(String raw)=>sha256.convert(utf8.encode(raw)).toString();
 final Map<String,WaffraSmsLifecycleEvidence> _prior={};
 final Map<String,String> _nativeSources={};
 final Map<String,int> _lastSeen={};

 WaffraSmsRelatedEvent inspectAndRemember(
  WaffraSmsLifecycleEvidence event,{String? nativeId}){
  final key=event.relationKey;
  if(key==null)return WaffraSmsRelatedEvent.none;
  // Never persist the raw bank reference, suffix, amount or sender.
  final hash=digest(key);
  final source=nativeId==null?null:digest(nativeId);
  final previous=_prior[hash];
  final previousSource=_nativeSources[hash];
  _prior[hash]=event;
  if(source!=null){
   _nativeSources[hash]=source;
   _lastSeen[hash]=DateTime.now().millisecondsSinceEpoch;
  }
  // Re-reading the SAME native pending queue item cannot flag itself as
  // a financial duplicate, even across a restart.
  if(source!=null&&source==previousSource)return WaffraSmsRelatedEvent.none;
  if(previous==null)return WaffraSmsRelatedEvent.none;
  if(event.stage==previous.stage){
   return WaffraSmsRelatedEvent.possibleDuplicate;
  }
  if(previous.stage==WaffraSmsLifecycleStage.pending&&
     event.stage==WaffraSmsLifecycleStage.posted){
   return WaffraSmsRelatedEvent.possibleSettlement;
  }
  if(event.stage==WaffraSmsLifecycleStage.reversed||
     event.stage==WaffraSmsLifecycleStage.refunded){
   return WaffraSmsRelatedEvent.possibleReversal;
  }
  return WaffraSmsRelatedEvent.relatedNeedsReview;
 }

 /// Intended only for owner-verified encrypted hint storage. Never send it
 /// to a financial writer or use it for native SMS exclusion/ACK.
 List<Map<String,Object?>> safeHistory({int maxRecords=256}){
  final values=<Map<String,Object?>>[];
  for(final entry in _prior.entries){
   final source=_nativeSources[entry.key];
   final seen=_lastSeen[entry.key];
   if(source==null||seen==null)continue;
   values.add(<String,Object?>{
    'key':entry.key,'source':source,
    'stage':entry.value.stage.name,'seenAt':seen,
   });
  }
  values.sort((a,b)=>(b['seenAt'] as int).compareTo(a['seenAt'] as int));
  return List<Map<String,Object?>>.unmodifiable(values.take(maxRecords));
 }
}
