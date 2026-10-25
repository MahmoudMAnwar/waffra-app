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
   .replaceAll(RegExp(r'^[;:：\s]+|[;:：\s]+$'),'')
   // Remove a terminal ID only when directly attached to Latin letters.
   // Dart's replaceAllMapped preserves the captured letter safely.
   .replaceAllMapped(RegExp(r'([A-Za-z])\d{4,6}$'),
    (terminal)=>terminal.group(1)??'').trim();
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
/// Deterministic Saudi merchant classification shared by Arabic and English
/// bank SMS. The returned category is ALWAYS the Arabic catalog identity:
/// the current app language only translates it for display, never persistence.
///
/// Conservative matching: strong brands first, generic merchant labels later.
/// Card/account numbers and payment rails never count as merchant evidence.
/// A doctor token must stand alone ("DR ALI"), never "DRIVE" or "ADDRESS".
String? waffraRecognizedMerchantLeaf(String merchant,{required bool income}){
 if(income)return null;
 final key=waffraNormalizeMerchantName(merchant);
 if(key.isEmpty)return null;
 bool any(List<String> terms)=>terms.any((term)=>
  key==term||key.startsWith('$term ')||key.contains(' $term ')||
  key.endsWith(' $term'));
 bool pattern(String regex)=>RegExp(regex,caseSensitive:false).hasMatch(key);

 // Delivery brands are distinct from grocers: Keeta != Keemart.
 if(any(['keemart','كي مارت','كيمارت','lulu hyper','lulu market',
  'لولو','alothaim','othaim','العثيم','panda ret','panda retail',
  'بنده','بن داود','bindawood','bin dawood','tamimi','التميمي',
  'danube','الدانوب','carrefour','كارفور','nesto','نيستو',
  'nana market','nana express','نعناع','farm supermarket',
  'manuel market','أسواق المزرعة','hypermarket','سوبرماركت',
  'supermarket','grocery','بقالة','groceries']))
  return 'بقالة وتموين / سوبرماركت';
 if(any(['keeta','كيتا','jahez','جاهز','hungerstation','هنقرستيشن',
  'toyou','تويو','the chefz','ذا شفز','mrsool food','مرسول فود']))
  return 'مطاعم وكافيهات / توصيل الطعام';

 if(any(['alnahdi pharmacy','nahdi pharmacy','النهدي','al dawa',
  'aldawaa','al dawaa','الدواء','pharmacy','صيدلية','chemist',
  'boots pharmacy','وايتس','whites pharmacy']))
  return 'صحة / صيدلية وأدوية';
 if(any(['marakez medical','marakez medical compan','medical compan',
  'مراكز الطبية','medical center','medical centre','clinic','clinics',
  'عيادة','عيادات','polyclinic','مستوصف','مجمع طبي']))
  return 'صحة / عيادات';
 if(pattern(r'(^| )dr\.?( |$)|(^| )doctor( |$)|(^| )دكتور( |$)|(^| )دكتورة( |$)|(^| )طبيب( |$)|(^| )طبيبة( |$)'))
  return 'صحة / أطباء';
 if(any(['hospital','مستشفى','hospital group','al habib hospital',
  'المواساة','mouwasat','mowasat','الحبيب الطبي']))
  return 'صحة / مستشفيات';
 if(any(['dental','dentist','اسنان','أسنان','orthodontic']))
  return 'صحة / أسنان';
 if(any(['optics','optical','optician','نظارات','بصريات']))
  return 'صحة / عيون ونظارات';
 if(any(['lab','laboratories','مختبر','تحاليل']))
  return 'صحة / تحاليل مخبرية';
 if(any(['physiotherapy','physical therapy','علاج طبيعي']))
  return 'صحة / علاج طبيعي';

 if(any(['jeeny','جيني','taxi','تاكسي']))return 'مواصلات / تاكسي';
 if(any(['uber','أوبر','careem ride','كريم تاكسي','bolt taxi']))
  return 'مواصلات / أوبر وكريم';
 if(any(['riyadh metro','riyadh bus','مترو الرياض','حافلات الرياض',
  'saptco','سابتكو']))return 'مواصلات / مترو وحافلات';
 if(any(['parking','مواقف','mawgif','موقف']))return 'مواصلات / مواقف سيارات';
 if(any(['petromin','petro','aramco station','أرامكو محطة',
  'محطة وقود','بنزين','fuel station','gas station','adnoc','shell fuel']))
  return 'السيارة / بنزين ووقود';
 if(any(['car wash','غسيل سيارات','غسيل سيارة']))
  return 'السيارة / غسيل سيارة';

 if(any(['shein','شي ان','شي إن','max fashion','centrepoint',
  'centerpoint','سنتر بوينت','redtag','ردتاغ','hm fashion',
  'zara','زارا']))return 'تسوّق / ملابس';
 if(any(['noon','نون','amazon sa','amazon','أمازون','aliexpress',
  'علي اكسبرس','temu','تيمو','salla store','زد ستور']))
  return 'تسوّق / تسوق إلكتروني';
 if(any(['jarir','جرير','virgin megastore','مكتبة جرير']))
  return 'تسوّق / قرطاسية';
 if(any(['ikea','ايكيا','إيكيا']))
  return 'سكن / أثاث';

 if(any(['shawarma','شاورما','burger','برجر','pizza','بيتزا',
  'kfc','كنتاكي','mcdonalds','ماكدونالدز','البيك','albaik',
  'herfy','هرفي','hardees','هارديز','subway food','بيت الشاورما']))
  return 'مطاعم وكافيهات / وجبات سريعة';
 if(any(['restaurant','مطعم','مطاعم','مطابخ','food court']))
  return 'مطاعم وكافيهات / مطاعم شعبية';
 if(any(['coffee','cafe','café','كوفي','قهوة','كافيه','starbucks',
  'ستاربكس','dunkin','دانكن','barns','بارنز']))
  return 'مطاعم وكافيهات / مقاهي';
 if(any(['bakery','مخبز','مخابز']))
  return 'مطاعم وكافيهات / مخابز';

 if(any(['stc telecom','stc bill','stc mobile','mobily','موبايلي',
  'zain telecom','زين اتصالات','jawwy','جوي','virgin mobile',
  'سلام موبايل','telecom','اتصالات']))
  return 'فواتير / جوال';
 // STC Pay, AlinmaPay and Mada are payment rails, NOT telecom shops.
 if(any(['electricity','الكهرباء','secco','الشركة السعودية للكهرباء']))
  return 'فواتير / كهرباء';
 if(any(['water company','شركة المياه','nwc water','مياه وطنية']))
  return 'فواتير / مياه';
 if(any(['fiber internet','internet bill','انترنت منزلي','إنترنت منزلي']))
  return 'فواتير / إنترنت منزلي';
 if(any(['rent','إيجار','ايجار','ejar','إيجار شهري']))
  return 'سكن / إيجار شهري';
 if(any(['school','مدرسة','مدارس','school fees']))
  return 'تعليم / رسوم مدارس';
 if(any(['university','جامعة','universities','رسوم جامعية']))
  return 'تعليم / رسوم جامعات';
 if(any(['udemy','coursera','دورة تدريبية','training course']))
  return 'تعليم / دورات تدريبية';
 if(any(['fitness time','وقت اللياقة','ليجام','leejam','gym','جيم',
  'fitness center','fitness centre']))
  return 'رياضة ولياقة / اشتراك نادي';
 if(any(['netflix','نتفليكس','shahid','شاهد vip','disney plus']))
  return 'اشتراكات رقمية / بث أفلام';
 if(any(['spotify','سبوتيفاي','anghami','أنغامي','apple music']))
  return 'اشتراكات رقمية / بث موسيقى';
 if(any(['openai','chatgpt','claude ai','anthropic','gemini advanced']))
  return 'اشتراكات رقمية / اشتراكات ذكاء اصطناعي';
 if(any(['cloud storage','icloud','google one','dropbox']))
  return 'اشتراكات رقمية / خدمات سحابية';
 if(any(['cinema','سينما','vox cinemas','موفي سينما','muvi cinema']))
  return 'ترفيه / سينما';
 if(any(['hotel','فندق','hotels','booking hotel']))
  return 'سفر وسياحة / فنادق';
 if(any(['saudia airlines','الخطوط السعودية','flynas','طيران ناس',
  'flyadeal','طيران أديل','airlines','flight ticket']))
  return 'سفر وسياحة / تذاكر طيران';
 return null;
}

/// Optional high-confidence hint from the operation itself (not app locale).
/// Never use the payee name for income classification, since a payment
/// gateway, personal sender, and refund merchant can have the same label.
String? waffraRecognizedSmsLeaf(String sms,{
 required bool income,String? merchant,
}){
 final header=sms.trimLeft().split('\n').first.trim().toLowerCase();
 if(income){
  if(RegExp(r'راتب|salary|payroll|salary credit|salary deposit',
      caseSensitive:false).hasMatch(header))return 'راتب / راتب أساسي';
  if(RegExp(r'refund|reversal credit|استرداد|استرجاع|مبلغ مسترد',
      caseSensitive:false).hasMatch(header))return 'مبالغ مستردة / استرجاع مشتريات';
  if(RegExp(r'credit via local transfer|local incoming transfer|حوالة.*واردة|تحويل.*وارد',
      caseSensitive:false).hasMatch(header))return 'حوالات واردة / حوالة محلية';
  if(RegExp(r'international incoming transfer|حوالة دولية واردة',
      caseSensitive:false).hasMatch(header))return 'حوالات واردة / حوالة دولية';
  return null;
 }
 // Transfer direction is financial, unrelated to whether a bank is named.
 if(RegExp(r'local outgoing transfer|debit via local transfer|حوالة محلية صادرة',
     caseSensitive:false).hasMatch(header))return 'تحويلات / حوالات محلية';
 if(RegExp(r'international outgoing transfer|حوالة دولية صادرة',
     caseSensitive:false).hasMatch(header))return 'تحويلات / حوالات دولية';
 if(merchant!=null){
  final known=waffraRecognizedMerchantLeaf(merchant,income:false);
  if(known!=null)return known;
 }
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
