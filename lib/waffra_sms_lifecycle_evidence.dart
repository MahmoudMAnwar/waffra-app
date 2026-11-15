import 'waffra_bank_sms_facts.dart';
import 'waffra_sms_multicurrency_review.dart';
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
   final money=WaffraSmsCurrencies.originalAmount(body);
   if(suffix!=null&&money?.currency=='SAR'&&money!.amount>0){
    final scaled=money.amount*100;
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
 final Map<String,WaffraSmsLifecycleEvidence> _prior={};
 WaffraSmsRelatedEvent inspectAndRemember(WaffraSmsLifecycleEvidence event){
  final key=event.relationKey;
  if(key==null)return WaffraSmsRelatedEvent.none;
  final previous=_prior[key];
  _prior[key]=event;
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
}
