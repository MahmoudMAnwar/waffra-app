import 'waffra_bank_sms_facts.dart';
import 'waffra_sms_multicurrency_review.dart';
import 'waffra_sms_account_learning.dart';
import 'waffra_merchant_rules.dart';
import 'waffra_sms_saudi_template_registry.dart';
import 'waffra_saudi_financial_providers.dart';

/// M987: read-only bank-message facts. The parser is offline and never
/// authorizes an account association, SMS ACK, finance write or category.
class WaffraSmsStructuredBankContext {
 const WaffraSmsStructuredBankContext({
  required this.facts,required this.pending,required this.composite,
  required this.requiresReview,this.providerId,this.merchant,
  this.principalSar,this.referenceAmountSar,this.feeSar,this.vatSar,
  this.accountLastFour,this.reference,this.templateFamily,this.templateVersion,
  this.sourceCurrencies=const <String>{},this.sourceAmount,
 });
 final WaffraBankSmsFacts facts;
 final String? providerId,merchant,accountLastFour,reference,templateFamily;
 final int? templateVersion;
 final Set<String> sourceCurrencies;
 final ({double amount,String currency,String formatted})? sourceAmount;
 /// The quoted SAR amount is retained for related-event proposals only.
 /// Fees and VAT are read-only, never added to principal automatically.
 final double? principalSar,referenceAmountSar,feeSar,vatSar;
 final bool pending,composite,requiresReview;


 /// Strictly labelled SAR VAT only. A missing currency is not assumed SAR;
 /// no unlabelled number, fee, balance or foreign VAT is returned.
 static final _vatCue=RegExp(
  r'\bvat\b|value\s+added\s+tax|ضريب',
  caseSensitive:false);
 static final _labelledVat=RegExp(
  r'^\s*(?:vat|value\s+added\s+tax|'
  r'ضريبة(?:\s+القيمة\s+المضافة)?|الضريبة)\s*[:：-]?\s*'
  r'(?:(?:SAR|SR|ريال)\s*([0-9]+(?:\.[0-9]{1,2})?)|'
  r'([0-9]+(?:\.[0-9]{1,2})?)\s*(?:SAR|SR|ريال))\s*$',
  caseSensitive:false);
 static double? quotedVatSar(String body){
  if(!_vatCue.hasMatch(body))return null;
  const ar='٠١٢٣٤٥٦٧٨٩',fa='۰۱۲۳۴۵۶۷۸۹';
  final digits=body.replaceAllMapped(RegExp(r'[٠-٩۰-۹]'),(m){
   final c=m.group(0)!;
   return (ar.contains(c)?ar.indexOf(c):fa.indexOf(c)).toString();
  }).replaceAll('٫','.').replaceAll('٬',',');
  double? found;
  for(final piece in digits.split(RegExp(r'[\r\n;|]+'))){
   if(!_vatCue.hasMatch(piece))continue;
   final match=_labelledVat.firstMatch(piece);
   if(match==null||found!=null)return null;
   final value=double.tryParse(match.group(1)??match.group(2)??'');
   if(value==null||!value.isFinite||value<0||value>1e8)return null;
   final minor=value*100;
   if((minor-minor.round()).abs()>0.000001)return null;
   found=value;
  }
  return found;
 }

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
  final template=WaffraSaudiSmsTemplateRegistry.identify(
   providerId:provider,body:body,multipleFinancialEvents:composite,
   securityChallenge:bank.securityChallenge);
  final sourceCurrencies=WaffraSmsCurrencies.currenciesForMessage(body);
  final amount=WaffraSmsCurrencies.originalAmount(body,
   detectedCurrencies:sourceCurrencies);
  final referenceAmountSar=amount?.currency=='SAR'?amount?.amount:null;
  final currencySafe=amount?.currency=='SAR'&&
   sourceCurrencies.length==1&&sourceCurrencies.single=='SAR';
  final direction=bank.kind==WaffraBankOperationKind.income||
    bank.kind==WaffraBankOperationKind.expense||
    bank.kind==WaffraBankOperationKind.transfer;
  final unsafe=pending||composite||!direction;
  // Even with a recognized bank sender, the final four digits are only
  // a user-editable proposal. A bank sender is not account ownership proof.
  final income=bank.kind==WaffraBankOperationKind.income;
  // Digital wallets have independent identifiers and must never inherit
  // a bank/card suffix from a sender template without explicit review.
  final bankLike=provider!=null&&
   WaffraSaudiFinancialProviders.byId(provider)?.category!=
    WaffraSaudiFinancialProviders.wallet;
  final suffix=bankLike&&!unsafe&&
    bank.kind!=WaffraBankOperationKind.transfer?
   WaffraBankSmsFactsParser.suggestedAccountLastFour(
    body,income:income,preParsed:bank):null;
  final merchant=unsafe?null:waffraMerchantName(body,income:income);
  return WaffraSmsStructuredBankContext(
   facts:bank,pending:pending,composite:composite,
   providerId:provider,reference:bank.reference,
   templateFamily:template?.family,templateVersion:template?.version,
   sourceCurrencies:sourceCurrencies,sourceAmount:amount,
   merchant:merchant,accountLastFour:suffix,
   principalSar:unsafe||!currencySafe?null:amount!.amount,
   referenceAmountSar:referenceAmountSar,
   feeSar:bank.fee,vatSar:quotedVatSar(body),
   requiresReview:unsafe||!currencySafe||
    bank.kind==WaffraBankOperationKind.transfer,
  );
 }
}
