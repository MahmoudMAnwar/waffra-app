/// Extract facts from a bank SMS without making accounting assumptions.
/// M419: account suffix, transfer fee, counterpart and transaction kind
/// are separate fields; a transfer is NEVER implicitly "an expense".
enum WaffraBankOperationKind {
 income, expense, transfer, cardSettlement, uncertain
}

class WaffraBankSmsFacts {
 const WaffraBankSmsFacts({
  required this.kind,
  this.sourceSuffix,
  this.destinationSuffix,
  this.fee,
  this.reference,
  this.counterparty,
  this.pending=false,this.securityChallenge=false,
 });
 final WaffraBankOperationKind kind;
 final String? sourceSuffix,destinationSuffix,reference,counterparty;
 final double? fee;
 final bool pending,securityChallenge;
 bool get canAutoPostAsIncomeExpense=>
  !pending&&(kind==WaffraBankOperationKind.income||
             kind==WaffraBankOperationKind.expense);
}

abstract final class WaffraBankSmsFactsParser {
 static final _transfer=RegExp(
  r'\b(?:outgoing|incoming|internal)\s+(?:bank\s+)?transfer\b|'
  r'\b(?:transfer\s+(?:received|sent|in|out|to)|credit\s+transfer|'
  r'debit\s+transfer|funds\s+transferred)\b|'
  r'حوال[ةه](?:\s+مالي[ةه])?\s+(?:صادر[ةه]|وارد[ةه])|'
  r'تحويل\s+(?:بنكي\s+)?(?:صادر|وارد|بين)|عملية\s+حوال[ةه]|'
  r'حوال[ةه]\s+داخلي[ةه]|تحويل\s+داخل[يى]|تحويل\s+بين\s+حسابات',
  caseSensitive:false);
 static final _card=RegExp(
  r'\b(?:credit\s+card\s+(?:payment|settlement)|'
  r'card\s+balance\s+payment|card\s+bill\s+payment)\b|'
  r'سداد\s+(?:فاتور[ةه]\s+)?(?:بطاق[ةه]|ائتماني[ةه])',
  caseSensitive:false);
 static final _income=RegExp(
  r'\b(?:credited|received|salary\s+deposit|refund\s+received|'
  r'incoming\s+transfer|credit\s+transfer|deposit)\b|'
  r'حوال[ةه].{0,35}وارد|تحويل.{0,35}وارد|راتب|إيداع',
  caseSensitive:false);
 static final _expense=RegExp(
  r'\b(?:purchase|debited|withdrawal|pos|paid|payment)\b|'
  r'شراء|خصم|سحب|دفع|شحن\s*(?:الجوال|جوال|الرصيد|رصيد|الهاتف)(?![ء-ي])|' +
  r'حوال[ةه].{0,35}صادر|تحويل.{0,35}صادر',
  caseSensitive:false);
 static final _pending=RegExp(
  r'\b(?:pending|declined|rejected|failed|cancelled|canceled|voided|reversed|reversal|unsuccessful|preauth|otp|'
  r'verification\s+code)\b|معلق[ةه]?|غير\s+مكتمل|مرفوض|ملغ[يىاهة]|'
  r'تم\s+(?:إلغاء|الغاء)|لم\s+تتم|لم\s+تكتمل|غير\s+ناجح[ةه]?|فشلت|عكس\s+العملي[ةه]|'
  r'رمز\s+(?:التحقق|التفعيل)',
  caseSensitive:false);
 /// Security/OTP evidence never authorizes a debit. Verified nonfinancial
 /// challenges are excluded by the same safe foreground/background rules;
 /// any mixed completed-money evidence stays in review.
 static final _securityChallenge=RegExp(
  r'\b(?:otp|one[ -]?time[ -]?(?:password|code|passcode)|'
  r'verification[ -]?code|security[ -]?code|authorization[ -]?code|'
  r'confirm(?:ation)?[ -]?code|temporary[ -]?(?:password|code))\b|'
  r'رمز\s*(?:مؤقت|التحقق|تفعيل|التفعيل|الدخول|تأكيد|التأكيد|الامان|الأمان|التوثيق|المصادقة|تسجيل\s+الدخول)|'
  r'(?:كود|رمز)\s*(?:تسجيل\s+الدخول|الدخول|التأكيد|التحقق|التوثيق|المصادقة)|'
  r'(?:رمزك|كودك|الكود\s+الخاص\s+بك)\s*(?:(?:هو|هي)\s*|[:：]\s*)[0-9٠-٩۰-۹]{4,8}|'
  r'\b(?:login|sign[ -]?in|authentication|auth|activation|access|2fa)\s+(?:pass)?code\b|'
  r'\byour\s+(?:(?:login|sign[ -]?in|security|verification|app)\s+)?code\s*(?:is|[:：])\s*[0-9]{4,8}\b|'
  // M1005: bilingual code notifications use reverse English word order.
  r'\b[0-9٠-٩۰-۹]{4,8}\s+is\s+your\s+code\s+for\s+[A-Za-z][A-Za-z0-9._-]{1,39}\b|'
  r'\bis\s+your\s+code\s+for\s+[A-Za-z][A-Za-z0-9._-]{1,39}\s+[0-9٠-٩۰-۹]{4,8}\b|'
  r'كلم[ةه]\s*مرور\s*مؤقت[ةه]?|'
  r'رمز\s*(?:إضافة|اضافة|تأكيد)\s*المستفيد',
  caseSensitive:false);
 static bool isVerificationChallenge(String raw)=>
  _securityChallenge.hasMatch(raw.replaceAll(
   RegExp(r'[\u200e\u200f\u061c\u064B-\u065F]'),' '));
 static final _source=RegExp(
  r'(?:من\s+(?:محفظ[ةه]|حساب|بطاق[ةه])|'
  r'(?:from|source|account|card|wallet|acct)\s*(?:no\.?|ending)?\s*[:：]?)'
  r'[^\r\n]{0,22}?(?:\*{2,}|x{2,}|X{2,})\s*([0-9٠-٩]{4})',
  caseSensitive:false);
 static final _destination=RegExp(
  r'(?:إلى|الى|إيبان|أيبان|ايبان|iban|to\s+(?:account|wallet|card)|destination)'
  r'[^\r\n]{0,45}?(?:\*{2,}|x{2,}|X{2,})\s*([0-9٠-٩]{4})',
  caseSensitive:false);
 static final _fee=RegExp(
  r'(?:الرسوم(?:\s+المستقطعة)?|رسوم(?:\s+(?:التحويل|مستقطعة))?|'
  r'fees?|commission)\s*[:：]?\s*'
  r'(?:SAR\s*)?([0-9٠-٩][0-9٠-٩,]*(?:\.[0-9٠-٩]{1,2})?)'
  r'\s*(?:(?:SAR|ر\.\s*س|ر\s+س|ريال)(?![A-Za-zء-ي]))?',
  caseSensitive:false);
 static final _ref=RegExp(
  r'(?:الرقم\s+المرجعي|رقم\s+العملية|reference(?:\s+number)?|ref)'
  r'\s*[:：#]?\s*([A-Z0-9-]{5,40})',
  caseSensitive:false);
 static final _counterparty=RegExp(
  r'(?:إلى|الى|لصالح|beneficiary|payee|to\s+person)'
  r'\s*[:：]\s*([^\r\n]{2,90})',
  caseSensitive:false);

 /// M985: the owner may review a bank/card's final four digits.
 /// Only explicitly masked or 'ends in' identifiers are suggestions;
 /// naked four-digit numbers could be an OTP, reference or amount.
 static String? suggestedAccountLastFour(String body,{
  required bool income,WaffraBankSmsFacts? preParsed,
 }){
  // The structured context already parsed these exact bank facts; reusing
  // them avoids a second fee, reference, suffix and OTP scan per SMS.
  final facts=preParsed??parse(body);
  if(facts.pending||facts.securityChallenge||
     (preParsed==null&&isVerificationChallenge(body))||
     facts.kind!=(income?WaffraBankOperationKind.income:
      WaffraBankOperationKind.expense))return null;
  final digits=body.replaceAllMapped(RegExp(r'[٠-٩۰-۹]'),(m){
   const ar='٠١٢٣٤٥٦٧٨٩',fa='۰۱۲۳۴۵۶۷۸۹';
   final ch=m.group(0)!;
   return (ar.contains(ch)?ar.indexOf(ch):fa.indexOf(ch)).toString();
  });
  final endings=<String>{
   if((income?facts.destinationSuffix:facts.sourceSuffix)!=null)
    (income?facts.destinationSuffix:facts.sourceSuffix)!,
  };
  final masked=RegExp(
   r'(?:حسابك|الحساب|حساب|بطاقتك|البطاقة|بطاقة|account|acct|card)'
   r'(?:\s+(?:number|no\.?|رقم))?\s*[:：#\-]?\s*'
   r'(?:\*{2,}|[xX]{2,}|[•●]{2,})\s*([0-9]{4})\b',
   caseSensitive:false);
  final ending=RegExp(
   r'(?:حسابك|الحساب|حساب|بطاقتك|البطاقة|بطاقة|account|acct|card)'
   r'\s+(?:المنتهي[ةه]?\s*(?:ب|بالرقم)?|'
   r'ending\s+(?:in|with)|ends\s+(?:in|with))'
   r'\s*[:：#\-]?\s*([0-9]{4})\b',
   caseSensitive:false);
  for(final matcher in <RegExp>[masked,ending]){
   for(final hit in matcher.allMatches(digits))endings.add(hit.group(1)!);
  }
  return endings.length==1?endings.single:null;
 }

 /// M985: advisory duplicate evidence across differently formatted SMS.
 /// Exact reference PLUS direction PLUS account suffix are required.
 /// Identical amounts alone never identify a bank transaction.
 static bool sameReferenceAccountHint(String first,String second){
  final a=parse(first),b=parse(second);
  if(a.pending||b.pending||a.kind!=b.kind||
     a.reference==null||b.reference==null||
     a.reference!.toUpperCase()!=b.reference!.toUpperCase())return false;
  if(a.kind!=WaffraBankOperationKind.income&&
     a.kind!=WaffraBankOperationKind.expense&&
     a.kind!=WaffraBankOperationKind.transfer)return false;
  if(a.kind==WaffraBankOperationKind.transfer){
   return a.sourceSuffix!=null&&a.destinationSuffix!=null&&
    a.sourceSuffix==b.sourceSuffix&&
    a.destinationSuffix==b.destinationSuffix;
  }
  final income=a.kind==WaffraBankOperationKind.income;
  final firstSuffix=suggestedAccountLastFour(first,income:income);
  final secondSuffix=suggestedAccountLastFour(second,income:income);
  return firstSuffix!=null&&firstSuffix==secondSuffix;
 }

 static WaffraBankSmsFacts parse(String raw){
  final normalized=raw.replaceAll(RegExp(r'[\u200e\u200f\u00a0]'),' ').trim();
  final header=normalized.split(RegExp(r'[\r\n]')).first;
  final securityChallenge=isVerificationChallenge(normalized);
  final isTransfer=_transfer.hasMatch(header);
  final isCard=_card.hasMatch(normalized);
  final incoming=_income.hasMatch(header);
  final outgoing=_expense.hasMatch(header);
  // M514 #449: "incoming credit" describes movement into this account,
  // NOT proof that the receiving owner also owns the source account.
  // Keep an otherwise unspecified "Credit Transfer" in manual transfer
  // review, but explicitly incoming/wāreda notices are income candidates.
  // M1009: SAMA describes payment-rail direction, not that both bank
  // accounts belong to this owner. Only an explicit own-account phrase is
  // a transfer candidate; external outgoing/incoming is expense/income.
  final ownAccountTransfer=RegExp(
   r'بين\s+حسابات(?:ك|ي)|الى\s+حسابك\s+(?:الجاري|الاستثماري)|'
   r'من\s+حسابك\s+(?:الجاري|الاستثماري)|'
   r'between\s+(?:your|my|own)\s+accounts|'
   r'to\s+your\s+(?:current|investment)\s+account|'
   r'from\s+your\s+(?:current|investment)\s+account',
   caseSensitive:false).hasMatch(header);
  final explicitlyIncoming=RegExp(
   r'حوال[ةه](?:\s+(?:مالي[ةه]|داخلي[ةه]))?\s+وارد[ةه]|'
   r'تحويل(?:\s+بنكي)?\s+وارد|'
   r'\bincoming\s+(?:bank\s+)?transfer\b|'
   r'\btransfer\s+received\b',
   caseSensitive:false).hasMatch(header);
  final explicitlyOutgoing=RegExp(
   r'حوال[ةه](?:\s+(?:مالي[ةه]|داخلي[ةه]|محلي[ةه]|دولي[ةه]))?\s+صادر[ةه]|'
   r'تحويل(?:\s+(?:بنكي|محلي|داخلي|دولي))?\s+صادر|'
   r'\b(?:outgoing|debit)\s+(?:bank\s+)?transfer\b|'
   r'\btransfer\s+(?:sent|out|to)\b',
   caseSensitive:false).hasMatch(header);
  final kind=securityChallenge?WaffraBankOperationKind.uncertain:
   isCard?WaffraBankOperationKind.cardSettlement:
   ownAccountTransfer&&isTransfer?WaffraBankOperationKind.transfer:
   explicitlyOutgoing&&!explicitlyIncoming?
    WaffraBankOperationKind.expense:
   explicitlyIncoming&&!explicitlyOutgoing?
    WaffraBankOperationKind.income:
   isTransfer?WaffraBankOperationKind.transfer:
   incoming&&!outgoing?WaffraBankOperationKind.income:
   outgoing&&!incoming?WaffraBankOperationKind.expense:
   WaffraBankOperationKind.uncertain;
  String? normalizeSuffix(String? value)=>value==null?null:
   value.replaceAll('٠','0').replaceAll('١','1').replaceAll('٢','2')
   .replaceAll('٣','3').replaceAll('٤','4').replaceAll('٥','5')
   .replaceAll('٦','6').replaceAll('٧','7').replaceAll('٨','8')
   .replaceAll('٩','9');
  final feeMatch=_fee.firstMatch(normalized);
  // M596: foreign, unparseable, or sub-halalah fees cannot become SAR.
  // Keep the SMS unposted if fee evidence is ambiguous.
  final feeMentioned=RegExp(
   r'الرسوم|رسوم|\bfees?\b|\bcommission\b',caseSensitive:false)
    .hasMatch(normalized);
  // Currency tokens belong to this fee CLAUSE only. A following
  // VAT/REF/Balance line is metadata, not a foreign currency on the fee.
  // Preserve eight same-line characters before the matched fee label and
  // sixteen after its amount, but never scan into a different field.
  final feePrefix=feeMatch==null?'':normalized.substring(0,feeMatch.start)
   .split(RegExp(r'[\r\n;|]')).last;
  final feeSuffix=feeMatch==null?'':normalized.substring(
   feeMatch.start,
   feeMatch.end+16<normalized.length?
    feeMatch.end+16:normalized.length
  ).split(RegExp(r'[\r\n;|]')).first;
  final feeWindow=(feePrefix.length>8?
    feePrefix.substring(feePrefix.length-8):feePrefix)+feeSuffix;
  final unsupportedFeeCurrency=RegExp(
   r'\b(?:USD|EUR|GBP|AED|KWD|BHD|QAR|OMR|JPY|CAD|AUD|CHF|CNY)\b',
   caseSensitive:false).hasMatch(feeWindow)||
   RegExp(r'\b(?!SAR\b)[A-Z]{3}\b|'
    r'دولار|درهم|دينار|يورو|جنيه',
    caseSensitive:true).hasMatch(feeWindow);
  final malformedFeeNumber=feeMatch!=null&&
   feeMatch.end<normalized.length&&
   RegExp(r'^[0-9٠-٩.,%٪]').hasMatch(normalized.substring(feeMatch.end));
  final feeRequiresReview=feeMentioned&&
   (feeMatch==null||unsupportedFeeCurrency||malformedFeeNumber);
  final fee=feeMatch==null||feeRequiresReview?null:
   double.tryParse(normalizeSuffix(feeMatch.group(1))!.replaceAll(',',''));
  return WaffraBankSmsFacts(
   kind:kind,
   sourceSuffix:normalizeSuffix(_source.firstMatch(normalized)?.group(1)),
   destinationSuffix:normalizeSuffix(_destination.firstMatch(normalized)?.group(1)),
   fee:fee!=null&&fee.isFinite&&fee>=0?fee:null,
   reference:_ref.firstMatch(normalized)?.group(1),
   counterparty:_counterparty.firstMatch(normalized)?.group(1)?.trim(),
   pending:securityChallenge||_pending.hasMatch(normalized)||feeRequiresReview,
   securityChallenge:securityChallenge,
  );
 }
 /// Display-only accounting preview. A fee never modifies an internal
 /// transfer until an atomic fee-aware verified finance writer is available.
 static int? extraDebitMinor({required int principalMinor,double? feeSar}){
  if(principalMinor<=0||feeSar==null||
     !feeSar.isFinite||feeSar<0)return null;
  final exactFee=feeSar*100;
  final feeMinor=exactFee.round();
  if((exactFee-feeMinor).abs()>0.000001||
     principalMinor>9007199254740991-feeMinor)return null;
  return principalMinor+feeMinor;
 }

}
