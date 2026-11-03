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
  this.pending=false,
 });
 final WaffraBankOperationKind kind;
 final String? sourceSuffix,destinationSuffix,reference,counterparty;
 final double? fee;
 final bool pending;
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
  r'تحويل\s+(?:بنكي\s+)?(?:صادر|وارد|بين)|عملية\s+حوال[ةه]',
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
  r'شراء|خصم|سحب|دفع|حوال[ةه].{0,35}صادر|تحويل.{0,35}صادر',
  caseSensitive:false);
 static final _pending=RegExp(
  r'\b(?:pending|declined|rejected|failed|preauth|otp|'
  r'verification\s+code)\b|معلق[ةه]?|غير\s+مكتمل|مرفوض|'
  r'رمز\s+(?:التحقق|التفعيل)',
  caseSensitive:false);
 static final _source=RegExp(
  r'(?:من\s+(?:محفظ[ةه]|حساب|بطاق[ةه])|'
  r'(?:from|source|account|card|wallet|acct)\s*(?:no\.?|ending)?\s*[:：]?)'
  r'[^\r\n]{0,22}?(?:\*{2,}|x{2,}|X{2,})\s*([0-9٠-٩]{4})',
  caseSensitive:false);
 static final _destination=RegExp(
  r'(?:إلى|الى|iban|to\s+(?:account|wallet|card)|destination)'
  r'[^\r\n]{0,45}?(?:\*{2,}|x{2,}|X{2,})\s*([0-9٠-٩]{4})',
  caseSensitive:false);
 static final _fee=RegExp(
  r'(?:الرسوم|رسوم\s+التحويل|fees?|commission)\s*[:：]?\s*'
  r'(?:SAR\s*)?([0-9٠-٩][0-9٠-٩,]*(?:\.[0-9٠-٩]{1,2})?)'
  r'\s*(?:SAR|ر\.?\s*س|ريال)?',
  caseSensitive:false);
 static final _ref=RegExp(
  r'(?:الرقم\s+المرجعي|رقم\s+العملية|reference(?:\s+number)?|ref)'
  r'\s*[:：#]?\s*([A-Z0-9-]{5,40})',
  caseSensitive:false);
 static final _counterparty=RegExp(
  r'(?:إلى|الى|لصالح|beneficiary|payee|to\s+person)'
  r'\s*[:：]\s*([^\r\n]{2,90})',
  caseSensitive:false);

 static WaffraBankSmsFacts parse(String raw){
  final normalized=raw.replaceAll(RegExp(r'[\u200e\u200f\u00a0]'),' ').trim();
  final header=normalized.split(RegExp(r'[\r\n]')).first;
  final isTransfer=_transfer.hasMatch(header);
  final isCard=_card.hasMatch(normalized);
  final incoming=_income.hasMatch(header);
  final outgoing=_expense.hasMatch(header);
  final kind=isCard?WaffraBankOperationKind.cardSettlement:
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
  final fee=feeMatch==null?null:
   double.tryParse(normalizeSuffix(feeMatch.group(1))!.replaceAll(',',''));
  return WaffraBankSmsFacts(
   kind:kind,
   sourceSuffix:normalizeSuffix(_source.firstMatch(normalized)?.group(1)),
   destinationSuffix:normalizeSuffix(_destination.firstMatch(normalized)?.group(1)),
   fee:fee!=null&&fee.isFinite&&fee>=0?fee:null,
   reference:_ref.firstMatch(normalized)?.group(1),
   counterparty:_counterparty.firstMatch(normalized)?.group(1)?.trim(),
   pending:_pending.hasMatch(normalized),
  );
 }
}
