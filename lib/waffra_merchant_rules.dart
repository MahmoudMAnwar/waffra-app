/// Merchant and counterparty identity extraction for Saudi bank SMS.
/// Never return a bank account or card suffix; return only the explicitly
/// printed merchant or person name. No external merchant lookup or bank API.
String? waffraMerchantName(String raw,{bool income=false}) {
 final text=raw.replaceAll('\u200f','').replaceAll('\u200e','')
  .replaceAll('\u061c','').replaceAll('\r\n','\n');
 final transfer=RegExp(r'حوال[ةه]|تحويل|transfer',caseSensitive:false).hasMatch(text);
 final matches=<RegExp>[];
 if(transfer){
  if(income){
   matches.add(RegExp(r'(?:^|\n)\s*من\s*(?:\d{2,6}\s*;\s*)?([^\n\r;]{2,100})',multiLine:true));
  }else{
   matches.add(RegExp(r'(?:^|\n)\s*لـ\s*(?:\d{2,6}\s*;\s*)?([^\n\r;]{2,100})',multiLine:true));
  }
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
  if(name.length<2||name.length>100||RegExp(r'^\d+$').hasMatch(name))continue;
  if(RegExp(r'^(?:مدى|mada|mada pay|sr|sar|pos|pay)$',caseSensitive:false).hasMatch(name))continue;
  // A generic payment rail is not a merchant and must not become a category.
  return name;
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
  final key=waffraNormalizeMerchantName(existing.group(1)??'');
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
 if(key.contains('alothaim')||key.contains('العثيم'))
  return 'بقالة وتموين / سوبرماركت';
 if(key.contains('petro')||key.contains('وقود'))
  return 'السيارة / بنزين ووقود';
 return null;
}

String waffraFallbackSmsParent({required bool income,required bool transfer}) =>
 income?'حوالات واردة':transfer?'تحويلات':'أخرى';
