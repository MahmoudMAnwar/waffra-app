import 'waffra_bank_sms_facts.dart';
import 'waffra_sms_multicurrency_review.dart';
import 'waffra_sms_account_learning.dart';
import 'waffra_merchant_rules.dart';

/// M987: read-only bank-message facts. The parser is offline and never
/// authorizes an account association, SMS ACK, finance write or category.
class WaffraSmsStructuredBankContext {
 const WaffraSmsStructuredBankContext({
  required this.facts,required this.pending,required this.composite,
  required this.requiresReview,this.providerId,this.merchant,
  this.principalSar,this.accountLastFour,this.reference,
 });
 final WaffraBankSmsFacts facts;
 final String? providerId,merchant,accountLastFour,reference;
 final double? principalSar;
 final bool pending,composite,requiresReview;

 /// An SMS with multiple independent action headers must be split or
 /// explicitly reviewed; never assume its first amount is the whole debit.
 static bool multipleEvents(String raw){
  final action=RegExp(
   r'^\s*(?:شراء(?:\s+pos)?|خصم(?:\s+مبلغ)?|سحب|'
   r'حوال[ةه](?:\s+(?:صادر[ةه]|وارد[ةه]))?|'
   r'تحويل(?:\s+(?:صادر|وارد))?|إيداع|ايداع|راتب|'
   r'(?:online\s+)?purchase|pos\s+purchase|'
   r'(?:incoming|outgoing|internal)\s+transfer|'
   r'(?:account\s+)?(?:debited|credited)|'
   r'(?:cash\s+)?withdrawal|salary\s+deposit|refund\s+received)'
   r'(?:\b|\s|[:：])',
   caseSensitive:false);
  var count=0;
  for(final clause in raw.split(RegExp(r'[\r\n;|]+'))){
   if(action.hasMatch(clause)&&++count>1)return true;
  }
  return false;
 }
 static WaffraSmsStructuredBankContext parse(String body,{
  required String sender,
 }){
  final bank=WaffraBankSmsFactsParser.parse(body);
  final pending=bank.pending||
   WaffraSmsCurrencies.isUnpostedNotice(body);
  final composite=multipleEvents(body);
  final provider=WaffraSmsAccountLearning.bankGroup(sender);
  final amount=WaffraSmsCurrencies.originalAmount(body);
  final currencySafe=amount?.currency=='SAR'&&
   !WaffraSmsCurrencies.requiresReviewForSarLedger(body);
  final direction=bank.kind==WaffraBankOperationKind.income||
    bank.kind==WaffraBankOperationKind.expense||
    bank.kind==WaffraBankOperationKind.transfer;
  final unsafe=pending||composite||!direction;
  // Even with a recognized bank sender, the final four digits are only
  // a user-editable proposal. A bank sender is not account ownership proof.
  final income=bank.kind==WaffraBankOperationKind.income;
  final suffix=provider!=null&&!unsafe&&
    bank.kind!=WaffraBankOperationKind.transfer?
   WaffraBankSmsFactsParser.suggestedAccountLastFour(
    body,income:income):null;
  final merchant=unsafe?null:waffraMerchantName(body,income:income);
  return WaffraSmsStructuredBankContext(
   facts:bank,pending:pending,composite:composite,
   providerId:provider,reference:bank.reference,
   merchant:merchant,accountLastFour:suffix,
   principalSar:unsafe||!currencySafe?null:amount!.amount,
   requiresReview:unsafe||!currencySafe||
    bank.kind==WaffraBankOperationKind.transfer,
  );
 }
}
