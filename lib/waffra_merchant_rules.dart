/// Merchant and counterparty identity extraction for Saudi bank SMS.
/// Never return a bank account or card suffix; return only the explicitly
/// printed merchant or person name. No external merchant lookup or bank API.
/// Refuse bank/card/account identifiers before they become a merchant label.
bool _waffraSafeMerchantCandidate(String name) {
  final value=name.trim();
  if(value.runes.length<2||value.runes.length>100||
      RegExp(r'^[0-9٠-٩۰-۹]+$').hasMatch(value))return false;
  if(RegExp(r'[0-9٠-٩۰-۹]{4,}|[*xX]{2,}[0-9٠-٩۰-۹]{2,}|iban|account|acct|card|حساب|بطاقة',
      caseSensitive:false).hasMatch(value))return false;
  return true;
}

String? waffraMerchantName(String raw,{bool income=false}) {
 final text=raw.replaceAll('\u200f','').replaceAll('\u200e','')
  .replaceAll('\u061c','').replaceAll('\r\n','\n');
 final transfer=RegExp(r'حوال[ةه]|تحويل|transfer',caseSensitive:false).hasMatch(text);
 final matches=<RegExp>[];
 if(transfer){
  if(income){
   matches.add(RegExp(r'(?:^|\n)\s*من\s*(?:\d{2,6}\s*;\s*)?([^\n\r;]{2,100})',multiLine:true));
   matches.add(RegExp(r'^\s*From\s*[:：]\s*([^\n\r;]{2,100})',multiLine:true,caseSensitive:false));
  }else{
   matches.add(RegExp(r'(?:^|\n)\s*لـ\s*(?:\d{2,6}\s*;\s*)?([^\n\r;]{2,100})',multiLine:true));
   matches.add(RegExp(r'^\s*To\s*[:：]\s*([^\n\r;]{2,100})',multiLine:true,caseSensitive:false));
  }
 }
 if(!transfer){
  matches.add(RegExp(r'^\s*(?:At|Merchant)\s*[:：]\s*([^\n\r;]{2,100})',
   multiLine:true,caseSensitive:false));
 }
 matches.addAll([
  RegExp(r'(?:^|\n)\s*لدى\s*[:：]?\s*([^\n\r;]{2,100})',multiLine:true),
  RegExp(r'(?:^|\n)\s*لـ\s*(?:\d{2,6}\s*;\s*)?([^\n\r;]{2,100})',multiLine:true),
 ]);
 for(final pattern in matches){
  final match=pattern.firstMatch(text);
  if(match==null)continue;
  final name=(match.group(1)??'').trim()
   .replaceAll(RegExp(r'\s+'),' ')
   .replaceAll(RegExp(r'^[;:：\s]+|[;:：\s]+$'),'');
  if(!_waffraSafeMerchantCandidate(name))continue;
  if(RegExp(r'^(?:مدى|mada|mada pay|sr|sar|pos|pay)$',caseSensitive:false).hasMatch(name))continue;
  // A generic payment rail is not a merchant and must not become a category.
  return name;
 }
 // Some Saudi POS notifications put the merchant next to the SAR amount,
 // rather than on a labelled "لدى" line. Extract only that bounded field;
 // never include the amount, date, card suffix or original SMS in a title.
 final pos=RegExp(r'شراء\s+pos\s+من\s+مدى\s+([^;\n\r]{2,100})',
     caseSensitive:false).firstMatch(text);
 if(pos!=null){
  final merchant=(pos.group(1)??'')
   .replaceAll(RegExp(r'\bSAR\s*\d+(?:[.,]\d+)?\b',caseSensitive:false),' ')
   .replaceAll(RegExp(r'\b\d{1,2}/\d{1,2}/\d{2,4}\b'),' ')
   .replaceAll(RegExp(r'\s+'),' ').trim();
  if(_waffraSafeMerchantCandidate(merchant))return merchant;
 }
 return null;
}

String waffraNormalizeMerchantName(String name){
 var key=name.trim().toLowerCase()
  .replaceAll(RegExp(r'[\u200e\u200f\u061c]'),'')
  .replaceAll(RegExp(r'[^a-z0-9\u0621-\u064a ]'),' ')
  .replaceAll(RegExp(r'\s+'),' ');
 key=key.replaceAll('shawerma','shawarma')
  .replaceAll('shawrma','shawarma');
 return key.trim();
}

/// Stable merchant-name identity, never derived from the bank/card number.
String? waffraMerchantKey(String raw,{bool income=false}){
 final extracted=waffraMerchantName(raw,income:income);
 if(extracted!=null){
  final key=waffraNormalizeMerchantName(extracted);
  return key.isEmpty?null:key;
 }
 // User-corrected historical transactions may have a descriptive title.
 final existing=RegExp(r'(?:شراء|حوالة|شراء نقاط بيع)\s*[—-]\s*([^—\n]{2,100})')
  .firstMatch(raw);
 if(existing!=null){
  final candidate=(existing.group(1)??'').trim();
  if(!_waffraSafeMerchantCandidate(candidate))return null;
  final key=waffraNormalizeMerchantName(candidate);
  return key.isEmpty?null:key;
 }
 return null;
}

/// Business identity and financial classification are separate. Only
/// unambiguous names get an automatic leaf prediction; unknowns keep their
/// own child inside Other / Incoming Transfers / Transfers.
String? waffraRecognizedMerchantLeaf(String merchant,{required bool income}){
 if(income)return null;
 final key=waffraNormalizeMerchantName(merchant);
 if(key.contains('shawarma')||key.contains('شاورما'))
  return 'مطاعم وكافيهات / وجبات سريعة';
 if(key.contains('openai')&&key.contains('chatgpt'))
  return 'اشتراكات رقمية / اشتراكات ذكاء اصطناعي';
 if(key.contains('panda ret')||key.contains('بنده'))
  return 'بقالة وتموين / سوبرماركت';
 if(key.contains('alothaim')||key.contains('العثيم')||
    key.contains('lulu hyper')||key.contains('lulu market'))
  return 'بقالة وتموين / سوبرماركت';
 if(key.contains('alnahdi pharmacy')||key.contains('nahdi pharmacy'))
  return 'صحة / صيدلية وأدوية';
 if(key.contains('marakez medical')||key.contains('medical compan'))
  return 'صحة / عيادات';
 if(key=='keeta'||key.startsWith('keeta '))
  return 'مطاعم وكافيهات / توصيل الطعام';
 if(key=='jeeny'||key.startsWith('jeeny '))
  return 'مواصلات / تاكسي';
 if(key.contains('shein'))
  return 'تسوّق / ملابس';
 if(key=='noon'||key.startsWith('noon ')||key=='amazon sa')
  return 'تسوّق / تسوق إلكتروني';
 if(key.contains('petro')||key.contains('وقود'))
  return 'السيارة / بنزين ووقود';
 return null;
}

String waffraFallbackSmsParent({required bool income,required bool transfer}) =>
 income?'حوالات واردة':transfer?'تحويلات':'أخرى';

/// Bank SMS titles must NEVER include copied raw messages or account/card
/// identifiers. The parser supplies one of these fixed operation labels;
/// unknown labels fall back to a generic kind instead of echoing text.
String waffraSafeSmsTransactionTitle(String parsedTitle,String rawSms,
    {required bool income}) {
  const operations=<String>{
    'راتب','حوالة واردة','حوالة صادرة','شراء نقاط بيع',
    'مبلغ وارد','عملية بنكية',
  };
  final label=parsedTitle.trim();
  final base=operations.contains(label)?label:
    (income?'مبلغ وارد':'عملية بنكية');
  final merchant=waffraMerchantName(rawSms,income:income);
  if(merchant==null)return base;
  final title='$base — $merchant';
  return title.runes.length<=250?title:base;
}
