import 'waffra_saudi_financial_providers.dart';
import 'waffra_bank_sms_facts.dart';

/// Versioned, offline *read-only* Saudi bank/SMS display template registry.
/// A sender matching this allowlist is NOT proof of account ownership.
class WaffraSaudiSmsTemplateMatch {
 const WaffraSaudiSmsTemplateMatch({
  required this.version,required this.providerId,required this.family,
 });
 final int version;
 final String providerId,family;
 String get fixtureId=>'sa-v$version:$providerId:$family';
}

/// The registry intentionally does not return a financial amount, timestamp,
/// category, account or permission to exclude/acknowledge a native message.
abstract final class WaffraSaudiSmsTemplateRegistry {
 static const version=1;
 static final _purchase=RegExp(
  r'شراء|مشتريات|عملية\s+مدى|نقاط\s+البيع|'
  r'\b(?:purchase|pos\s+(?:transaction|purchase)|card\s+purchase)\b',
  caseSensitive:false);
 static final _transferOutgoing=RegExp(
  r'حوال[ةه]\s+صادر[ةه]|تحويل\s+(?:بنكي\s+)?صادر|'
  r'\b(?:outgoing\s+transfer|transfer\s+sent|debit\s+transfer)\b',
  caseSensitive:false);
 static final _transferIncoming=RegExp(
  r'حوال[ةه]\s+وارد[ةه]|تحويل\s+(?:بنكي\s+)?وارد|'
  r'\b(?:incoming\s+transfer|transfer\s+received|credit\s+transfer)\b',
  caseSensitive:false);
 static final _salary=RegExp(r'راتب|إيداع\s+راتب|\bsalary\b',
  caseSensitive:false);
 static final _deposit=RegExp(r'إيداع|ايداع|\bdeposit\b',
  caseSensitive:false);
 static final _atm=RegExp(r'سحب\s+(?:نقدي|صراف)|\b(?:atm\s+withdrawal|cash\s+withdrawal)\b',
  caseSensitive:false);
 static final _bill=RegExp(
  r'سداد\s+(?:فاتور[ةه]|خدم[ةه])|\bbill\s+payment\b',
  caseSensitive:false);
 static final _cardSettlement=RegExp(
  r'سداد\s+(?:بطاق[ةه]|ائتماني[ةه])|'
  r'\b(?:credit\s+card\s+(?:payment|settlement)|card\s+bill\s+payment)\b',
  caseSensitive:false);
 static final _refund=RegExp(
  r'استرداد|عكس\s+العملي[ةه]|استرجاع|'
  r'\b(?:refund|refunded|reversal|reversed|chargeback|voided)\b',
  caseSensitive:false);
 static final _beneficiary=RegExp(
  r'تم\s+(?:إضافة|اضافة|تفعيل|تنشيط)\s+(?:ال)?مستفيد|'
  r'\bbeneficiary\s+(?:added|activated|registered)\b',
  caseSensitive:false);
 static final _balanceNotice=RegExp(
  r'^(?:الرصيد|رصيد\s+الحساب|available\s+balance|balance\s+inquiry)',
  caseSensitive:false);
 static final _walletTopup=RegExp(
  r'شحن\s+(?:المحفظ[ةه]|محفظتك)|تعبئ[ةه]\s+المحفظ[ةه]|'
  r'\b(?:wallet\s+top[ -]?up|top[ -]?up\s+(?:wallet|balance))\b',
  caseSensitive:false);
 static final _cashback=RegExp(
  r'كاش\s*باك|استرداد\s+نقدي\s+مكاف[أةه]|'
  r'\bcash\s*back\b',caseSensitive:false);
 static final _cardActivation=RegExp(
  r'تم\s+(?:تفعيل|تنشيط)\s+(?:ال)?بطاق[ةه]|'
  r'\bcard\s+(?:activated|activation)\b',caseSensitive:false);
 static final _pending=RegExp(
  r'معلق|معلّق|قيد\s+المعالج[ةه]|مرفوض|فشلت|ملغي|ملغى|'
  r'\b(?:pending|preauth|declined|rejected|failed|voided)\b',
  caseSensitive:false);

 static WaffraSaudiSmsTemplateMatch? identify({
  required String? providerId,required String body,
  bool multipleFinancialEvents=false,bool? securityChallenge,
 }){
  // Never turn a two-operation notification into one booking suggestion.
  if(multipleFinancialEvents||providerId==null||
     WaffraSaudiFinancialProviders.byId(providerId)==null)return null;
  final header=body.trim().split(RegExp(r'[\r\n;|]+')).first;
  if(header.trim().isEmpty)return null;
  String? family;
  // Safety state outranks a financial verb. This is not a financial writer.
  if(securityChallenge??WaffraBankSmsFactsParser.isVerificationChallenge(body)){
   family='verification';
  }else if(_beneficiary.hasMatch(header)){
   family='beneficiary_notice';
  }else if(_cardActivation.hasMatch(header)){
   family='card_activation';
  }else if(_balanceNotice.hasMatch(header)){
   family='balance_notice';
  }else if(_refund.hasMatch(header)){
   family='reversal_or_refund';
  }else if(_pending.hasMatch(header)){
   family='non_posted';
  }else if(_cashback.hasMatch(header)){
   family='cashback_notice';
  }else if(_walletTopup.hasMatch(header)){
   family='wallet_topup';
  }else if(_cardSettlement.hasMatch(header)){
   family='card_settlement';
  }else if(_salary.hasMatch(header)){
   family='salary';
  }else if(_transferOutgoing.hasMatch(header)&&
     !_transferIncoming.hasMatch(header)){
   family='outgoing_transfer';
  }else if(_transferIncoming.hasMatch(header)&&
     !_transferOutgoing.hasMatch(header)){
   family='incoming_transfer';
  }else if(_atm.hasMatch(header)){
   family='atm_withdrawal';
  }else if(_bill.hasMatch(header)){
   family='bill_payment';
  }else if(_deposit.hasMatch(header)){
   family='deposit';
  }else if(_purchase.hasMatch(header)){
   family='purchase';
  }
  if(family==null)return null;
  return WaffraSaudiSmsTemplateMatch(
   version:version,providerId:providerId,family:family);
 }
}
