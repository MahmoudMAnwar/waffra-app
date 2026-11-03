import 'waffra_sms_intelligence.dart';
import 'waffra_bank_sms_facts.dart';

/// M418: Fully local strict eligibility before an SMS can affect money.
/// An LLM suggestion can NEVER override these deterministically checked gates.
enum WaffraAutoSmsDisposition { post, review, ignore }

class WaffraAutoSmsDecision {
 const WaffraAutoSmsDecision(this.disposition,this.reason);
 final WaffraAutoSmsDisposition disposition;
 final String reason;
 bool get canPost=>disposition==WaffraAutoSmsDisposition.post;
}

/// Source and direction must both be independently trustworthy. The bank SMS
/// parser supplies the *actual extracted amount*; this class never derives it
/// from an unrelated balance or a language model's guessed amount.
abstract final class WaffraAutoSmsPolicy {
 static final _trustedSender=RegExp(
  r'alinma|inma|rajhi|snb|alahli|sabb|riyad|bilad|anb|saib|'
  r'jazira|jazeera|aljazira|bank|urpay|stcpay|stcbank|mobily.?pay',
  caseSensitive:false);
 static final _currency=RegExp(
  r'\b(?:SAR|SR)\b|ريال(?:\s+سعودي)?|ر\.?\s*س',
  caseSensitive:false);
 static final _incoming=RegExp(
  r'\b(?:credit transfer|incoming transfer|account credited|credited|'
  r'received|salary deposit|salary credit|cash deposit|refund received)\b|'
  r'حوال[ةه]\s+وارد[ةه]|تحويل\s+وارد|إيداع|ايداع|راتب|تم\s+الإيداع',
  caseSensitive:false);
 static final _outgoing=RegExp(
  r'\b(?:card purchase|purchase|debited|debit via|outgoing transfer|'
  r'withdrawal|spent|paid|payment to)\b|'
  r'شراء|خصم|سحب|دفع|سداد|حوال[ةه]\s+صادر[ةه]|تحويل\s+صادر',
  caseSensitive:false);
 static final _unsafe=RegExp(
  r'\b(?:otp|verification|one.time.password|pending|declined|failed|'
  r'pre.?auth|authorization hold|credit card payment|internal transfer|'
  r'available balance only|rejected)\b|'
  r'رمز\s*(?:التحقق|التفعيل)|معلق|مرفوض|فشلت|غير\s+مكتمل|'
  r'سداد\s+البطاق[ةه]|تحويل\s+بين\s+حساباتك',
  caseSensitive:false);
 static WaffraAutoSmsDecision decide({
  required String sender,
  required String sms,
  required double? parsedAmount,
  required bool parsedIncome,
  required bool foreignCurrency,
  required DateTime arrived,
  DateTime? verifiedDate,
  bool accountLinked=true,
  bool categoryActive=true,
 }) {
  if(sms.trim().isEmpty || sms.length>1600 || _unsafe.hasMatch(sms)||
      WaffraSmsIntelligence.isPendingOrUnconfirmed(sms)){
   return const WaffraAutoSmsDecision(WaffraAutoSmsDisposition.ignore,'not_confirmed');
  }
  // A transfer, card settlement or message with a separate fee cannot
  // be represented faithfully by an income/expense-only transaction record.
  // Preserve it for a dedicated account-to-account review; do not debit Cash.
  final facts=WaffraBankSmsFactsParser.parse(sms);
  if(facts.kind==WaffraBankOperationKind.transfer||
     facts.kind==WaffraBankOperationKind.cardSettlement||
     (facts.fee!=null&&facts.fee!>0)){
   return const WaffraAutoSmsDecision(
    WaffraAutoSmsDisposition.review,'requires_transfer_or_fee_ledger');
  }
  if(!facts.canAutoPostAsIncomeExpense){
   return const WaffraAutoSmsDecision(
    WaffraAutoSmsDisposition.review,'transaction_kind_uncertain');
  }
  // Source account suffix alone is NOT an identity-mapping authorization.
  // No typed bank account in the current MoneyEntry schema; do not silently
  // apply a real bank SMS to the app's generic Cash account.
  if(facts.sourceSuffix!=null){
   return const WaffraAutoSmsDecision(
    WaffraAutoSmsDisposition.review,'source_account_mapping_required');
  }
  if(!_trustedSender.hasMatch(sender)||RegExp(r'\d{6,}').hasMatch(sender)){
   return const WaffraAutoSmsDecision(WaffraAutoSmsDisposition.review,'untrusted_sender');
  }
  if(foreignCurrency||!_currency.hasMatch(sms)){
   return const WaffraAutoSmsDecision(WaffraAutoSmsDisposition.review,'currency_not_verified');
  }
  if(parsedAmount==null||!parsedAmount.isFinite||parsedAmount<=0||
      parsedAmount>1000000||(parsedAmount*100-(parsedAmount*100).round()).abs()>0.001){
   return const WaffraAutoSmsDecision(WaffraAutoSmsDisposition.review,'amount_not_verified');
  }
  final header=sms.trimLeft().split(RegExp(r'[\r\n]')).first;
  final incoming=_incoming.hasMatch(header);
  final outgoing=_outgoing.hasMatch(header);
  if(incoming==outgoing || (incoming!=parsedIncome)){
   return const WaffraAutoSmsDecision(WaffraAutoSmsDisposition.review,'direction_not_verified');
  }
  if(verifiedDate!=null && verifiedDate.isAfter(arrived.add(const Duration(days:2)))){
   return const WaffraAutoSmsDecision(WaffraAutoSmsDisposition.review,'invalid_source_date');
  }
  if(verifiedDate!=null && verifiedDate.isBefore(arrived.subtract(const Duration(days:365)))){
   return const WaffraAutoSmsDecision(WaffraAutoSmsDisposition.review,'stale_source_date');
  }
  if(!accountLinked){
   return const WaffraAutoSmsDecision(WaffraAutoSmsDisposition.review,'new_account_mapping_required');
  }
  if(!categoryActive){
   return const WaffraAutoSmsDecision(WaffraAutoSmsDisposition.review,'category_unavailable');
  }
  return const WaffraAutoSmsDecision(WaffraAutoSmsDisposition.post,'verified');
 }
}
