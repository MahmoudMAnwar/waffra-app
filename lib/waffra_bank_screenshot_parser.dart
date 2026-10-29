/// Conservative, offline bank-screenshot interpretation for receipt OCR.
/// A screenshot can contain many SMS bubbles, card IDs and UI labels.
/// No OCR result is trusted for an automatic finance write.
import 'waffra_receipt_ocr_parser.dart';

class WaffraOcrBankCandidate {
 const WaffraOcrBankCandidate({
  required this.amount, required this.income, required this.sourceText,
  this.merchant, this.date,
 });
 final double amount;
 final bool income;
 final String sourceText;
 final String? merchant;
 final DateTime? date;
}

abstract final class WaffraBankScreenshotParser {
 static final _action=RegExp(
  r'(?:شراء\s*(?:pos|نقاط)|\bpos\b|card\s+purchase|payment\s+at|'
  r'حوالة\s+واردة|تحويل\s+وارد|راتب|salary\s+(?:credit|deposit)|'
  r'استرداد\s+مبلغ|refund\s+received)',
  caseSensitive:false,
 );
 static final _incoming=RegExp(
  r'(حوالة\s+واردة|تحويل\s+وارد|راتب|salary|refund\s+received|استرداد\s+مبلغ)',
  caseSensitive:false,
 );
 static final _money=RegExp(
  r'(?<![0-9A-Za-z])(?:SAR|SR|ر\.?\s*س|ريال)\s*[:：]?\s*([0-9]{1,9}(?:[.,][0-9]{1,2})?)(?![0-9.,])'
  r'|(?<![0-9])([0-9]{1,9}(?:[.,][0-9]{1,2})?)(?![0-9.,])\s*(?:SAR|SR|ر\.?\s*س|ريال)',
  caseSensitive:false,
 );
 static final _date=RegExp(r'(?<![0-9])([0-9]{1,2})/([0-9]{1,2})/([0-9]{2,4})(?![0-9])');
 static final _excludeMerchant=RegExp(
  r'alrajhibank|rajhi\s*bank|الراجحي|الإنماء|الانماء|البنك|bank|'
  r'sar|رصيد|balance|عبر|بطاقة|مدى|mada|visa|mastercard|'
  r'purchase|شراء|pos|الوقت|التاريخ|yesterday|sender|replies|'
  r'رقم|المرجع|reference|invoice|فاتورة|total|إجمالي',
  caseSensitive:false,
 );

 static bool looksLikeBankScreenshot(String text) {
  final normalized=WaffraReceiptOcrParser.westernDigits(text);
  return _action.hasMatch(normalized)&&
   (RegExp(r'\b(?:SAR|SR|POS)\b|ريال|مدى|mada|bank|الراجحي|تحويل|حوالة',
    caseSensitive:false).hasMatch(normalized));
 }

 static List<WaffraOcrBankCandidate> candidates(String text) {
  final lines=WaffraReceiptOcrParser.westernDigits(text)
   .split(RegExp(r'[\r\n]+')).map((l)=>l.trim())
   .where((l)=>l.isNotEmpty).toList();
  final found=<WaffraOcrBankCandidate>[];
  for(var i=0;i<lines.length;i++){
   if(!_action.hasMatch(lines[i]))continue;
   var end=i+1;
   while(end<lines.length&&end<i+10&&!_action.hasMatch(lines[end]))end++;
   final chunk=lines.sublist(i,end);
   final amounts=<double>[];
   int? amountAt;
   for(var k=0;k<chunk.length;k++){
    final line=chunk[k];
    // Never read card numbers, account/balance rows, reference IDs or dates
    // as transaction amounts even when OCR inserted a currency token.
    if(RegExp(r'balance|رصيد|رقم\s*البطاقة|رقم\s*المرجع|reference|'
       r'account|حساب|متبقي|available',caseSensitive:false)
       .hasMatch(line))continue;
    for(final match in _money.allMatches(line)){
     final raw=match.group(1)??match.group(2);
     if(raw==null)continue;
     final value=WaffraReceiptOcrParser.amountFromText(raw);
     if(value!=null){amounts.add(value);amountAt??=k;}
    }
   }
   // Ambiguous or multiple money values require manual correction.
   if(amounts.length!=1)continue;
   DateTime? date;
   for(final line in chunk){
    final match=_date.firstMatch(line);
    if(match==null)continue;
    final day=int.tryParse(match.group(1)!),month=int.tryParse(match.group(2)!);
    var year=int.tryParse(match.group(3)!);
    if(day==null||month==null||year==null)continue;
    if(year<100)year+=2000;
    if(year<2010||year>DateTime.now().year+1)continue;
    final candidate=DateTime(year,month,day);
    if(candidate.day==day&&candidate.month==month&&candidate.year==year){
     date=candidate;break;
    }
   }
   String? merchant;
   final after=(amountAt??0)+1;
   for(var k=after;k<chunk.length;k++){
    final line=chunk[k];
    if(line.length>80||line.length<3||_excludeMerchant.hasMatch(line)||
      _date.hasMatch(line)||RegExp(r'[0-9]{3,}').hasMatch(line)||
      !RegExp(r'[A-Za-z\u0600-\u06FF]{3}').hasMatch(line))continue;
    merchant=line;break;
   }
   found.add(WaffraOcrBankCandidate(
    income:_incoming.hasMatch(chunk.first),
    amount:amounts.single,merchant:merchant,date:date,
    sourceText:chunk.join('\n'),
   ));
   i=end-1;
  }
  return List.unmodifiable(found);
 }
}
