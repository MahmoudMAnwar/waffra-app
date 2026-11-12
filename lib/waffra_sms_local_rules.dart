import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'waffra_bank_sms_facts.dart';
import 'waffra_merchant_rules.dart';

part 'waffra_sms_saudi_seed_rules.part.dart';

/// Local-only, user-reviewable SMS classification. Rules are suggestions:
/// neither this file nor the settings screen can post money or link an account.
class WaffraSmsLocalRule {
 const WaffraSmsLocalRule({
  required this.id,required this.name,required this.keywords,
  required this.income,required this.category,
  this.matchAll=true,this.sender='',this.builtIn=false,
  this.kind='',this.autoPost=false,this.accountId='',this.accountSuffix='',
  this.keywordCategories=const <String,String>{},
  this.templateFamily='',this.contextFragments=const <String>[],
 });
 final String id,name,category,sender;
 final List<String> keywords;
 final bool income,matchAll,builtIn,autoPost;
 final String kind,accountId,accountSuffix,templateFamily;
 /// Only fixed, personal-data-free context phrases are stored; they never
 /// become independent OR conditions for classification or SMS exclusion.
 final List<String> contextFragments;
 /// Category associated with each normalized phrase in an auto-learned bucket.
 /// Existing encrypted rules without this field keep their original category.
 final Map<String,String> keywordCategories;
 String get resolvedKind=>kind.isEmpty?(income?'income':'expense'):kind;
 bool get financial=>resolvedKind=='income'||resolvedKind=='expense';

 Map<String,Object?> toJson()=>{
  'id':id,'name':name,'keywords':keywords,'income':income,
  'category':category,'matchAll':matchAll,'sender':sender,
  'kind':resolvedKind,'autoPost':autoPost,'accountId':accountId,
  'accountSuffix':accountSuffix,
  if(keywordCategories.isNotEmpty)'keywordCategories':keywordCategories,
  if(templateFamily.isNotEmpty)'templateFamily':templateFamily,
  if(contextFragments.isNotEmpty)'contextFragments':contextFragments,
 };
 factory WaffraSmsLocalRule.fromJson(Map<String,dynamic> j){
  final keywords=(j['keywords'] as List?)
   ?.whereType<String>().toList(growable:false)??const <String>[];
  return WaffraSmsLocalRule(
   id:(j['id']??'').toString(),name:(j['name']??'').toString(),
   keywords:keywords,income:j['income']==true,
   category:(j['category']??'').toString(),
   matchAll:j['matchAll']!=false,
   sender:(j['sender']??'').toString(),
   kind:(j['kind']??'').toString(),autoPost:j['autoPost']==true,
   accountId:(j['accountId']??'').toString(),
   accountSuffix:(j['accountSuffix']??'').toString(),
   keywordCategories:j['keywordCategories']==null
    ?const <String,String>{}
    :Map<String,String>.from(j['keywordCategories'] as Map),
   templateFamily:(j['templateFamily']??'').toString(),
   contextFragments:(j['contextFragments'] as List?)
    ?.whereType<String>().toList(growable:false)??const <String>[],
  );
 }
}

/// Approved keywords only. Never suggest bank identifiers, long numbers,
/// statement balances, OTPs, account/card suffixes or unredacted SMS bodies.
abstract final class WaffraSmsLocalRules {
 static String normalized(String text)=>text.toLowerCase()
  .replaceAll(RegExp(r'[\u200e\u200f\u061c\u064B-\u065F\u0670]'),'')
  .replaceAll(RegExp(r'[أإآٱ]'),'ا')
  .replaceAll('ى','ي').replaceAll('ة','ه')
  .replaceAll(RegExp(r'\s+'),' ').trim();

 static bool safeKeyword(String text){
  final word=normalized(text);
  if(word.length<2||word.length>48||!RegExp(r'[a-z\u0621-\u064a]').hasMatch(word))return false;
  if(RegExp(r'[0-9٠-٩۰-۹]|\*|@|#|/|\\|:|\.|iban|otp|pin|password|'
    r'account|balance|card|reference|حساب|بطاق|الرصيد|الرقم|المرجع',
    caseSensitive:false).hasMatch(word))return false;
  return true;
 }

 static bool safeRuleKeyword(String text,String kind)=>safeKeyword(text)||
  (kind=='excluded'&&const <String>{'otp','pin'}.contains(normalized(text)));

 // Built-in phrases are manually curated and cannot contain amounts,
 // card suffixes or secrets. Keep user-learned keywords on the stricter
 // legacy safeKeyword policy; never accept arbitrary bank texts as a rule.
 static bool _safeSaudiSeedKeyword(String word,String kind){
  final text=normalized(word);
  if(text.length<2||text.length>48||
     !RegExp(r'[a-z\u0621-\u064a]').hasMatch(text)||
     RegExp(r'[0-9٠-٩۰-۹]|\*|@|#|/|\\|:').hasMatch(text))return false;
  if(kind!='excluded'&&RegExp(
    r'(^|[^a-z])(?:otp|pin|password|iban)([^a-z]|$)|'
    r'رمز التحقق|رمز التفعيل|كلمة المرور',
    caseSensitive:false).hasMatch(text))return false;
  return true;
 }

 // Learn only event-shaped patterns, never arbitrary personal-name,
 // amount or account fragments from a one-message exclusion.
 static bool _beneficiaryManagement(String body){
  final text=normalized(body);
  return RegExp(
   r'(?:تم|تمت)\s+(?:اضافه|تنشيط|تفعيل|تحديث|تعديل|حذف|الغاء)\s+'
   r'(?:بيانات\s+)?(?:ال)?مستفيد|'
   r'(?:beneficiary|payee)\s+(?:added|activated|updated|removed)',
   caseSensitive:false).hasMatch(text);
 }

 static List<String> _safeContextFragments(String body){
  final text=normalized(body);
  const fragments=<String>[
   'رمز التحقق','رمز التفعيل','رمز الدخول','رمز مؤقت',
   'verification code','security code','one time code',
   'اضافة المستفيد','تنشيط المستفيد','تفعيل المستفيد',
   'حوالة صادرة','حوالة واردة','تحويل صادر','تحويل وارد',
   'تم الخصم','تم الايداع','رسوم','salary','payroll',
   'purchase','payment','transfer','beneficiary',
  ];
  return fragments.where((p)=>text.contains(normalized(p))&&
   safeRuleKeyword(p,'excluded')).take(12).toList(growable:false);
 }

 static WaffraSmsLocalRule? _excludedStructuralTemplate({
  required String body,required String sender,
 }){
  final verification=WaffraBankSmsFactsParser.isVerificationChallenge(body);
  final beneficiary=_beneficiaryManagement(body);
  if((!verification&&!beneficiary)||_hasCompletedFinanceCue(body))return null;
  final family=verification?'verification':'beneficiary_management';
  final t=normalized(body);
  final anchor=verification?
   const <String>['رمز التحقق','رمز التفعيل','رمز الدخول','رمز مؤقت',
    'verification code','security code','one time code','otp']
    .firstWhere((p)=>t.contains(normalized(p)),orElse:()=> 'رمز التحقق'):
   'المستفيد';
  final rule=WaffraSmsLocalRule(
   id:'template_${sha256.convert(utf8.encode(
    '${normalized(sender)}|excluded|$family')).toString().substring(0,32)}',
   name:verification?'رسائل تحقق':'إدارة المستفيدين',
   keywords:[anchor],
   kind:'excluded',income:false,category:'',sender:sender.trim(),
   matchAll:true,autoPost:false,templateFamily:family,
   contextFragments:_safeContextFragments(body),
  );
  validate(rule);
  return rule;
 }

 static bool matches(WaffraSmsLocalRule rule,String body,{String sender=''}) {
  final trustedSeed=rule.builtIn&&rule.id.startsWith('sa_');
  if(rule.keywords.isEmpty||rule.keywords.any((word)=>
    trustedSeed?!_safeSaudiSeedKeyword(word,rule.resolvedKind):
    !safeRuleKeyword(word,rule.resolvedKind)))return false;
  if(rule.sender.isNotEmpty&&normalized(rule.sender)!=normalized(sender))return false;
  if(rule.templateFamily=='verification'){
   return WaffraBankSmsFactsParser.isVerificationChallenge(body)&&
    !_hasCompletedFinanceCue(body);
  }
  if(rule.templateFamily=='beneficiary_management'){
   return _beneficiaryManagement(body)&&!_hasCompletedFinanceCue(body);
  }
  final source=' ${normalized(body)} ';
  bool has(String keyword){
   final safe=normalized(keyword);
   if(safe.isEmpty)return false;
   // Boundaries prevent short English keywords matching arbitrary longer words.
   return source.contains(' $safe ')||
    source.contains(' $safe\n')||
    RegExp('(^|[^a-z\\u0621-\\u064a])${RegExp.escape(safe)}([^a-z\\u0621-\\u064a]|\u0024)')
     .hasMatch(source);
  }
  return rule.matchAll?rule.keywords.every(has):rule.keywords.any(has);
 }

 /// OTP plus a completed purchase/debit must remain in financial review.
 static bool _hasCompletedFinanceCue(String body)=>RegExp(
  r'\b(?:purchase|debited|credited|withdrawal|payment|paid|pos)\b|'
  r'شراء|خصم|سحب|دفع|إيداع|ايداع|راتب|'
  r'(?:تم|تمت)\s+(?:تحويل|ارسال|إرسال)\s+|'
  r'حوالة صادرة|حوالة واردة|'
  r'\b(?:transfer completed|transfer successful|funds transferred)\b',
  caseSensitive:false).hasMatch(body);

 /// Unlike generic bank words ("payment reminder" or "exclusive discount"),
 /// these are independent, affirmative signs of a COMPLETED bank movement.
 /// A ready-made exclusion must never ACK a message containing such evidence.
 static bool _hasPostedMoneyEvidence(String body){
  final facts=WaffraBankSmsFactsParser.parse(body);
  final posted=RegExp(
   r'\b(?:debited|credited|withdrawn|withdrawal|paid|pos)\b|'
   r'\b(?:transfer\s+(?:sent|received|completed|successful)|'
   r'funds\s+transferred|payment\s+(?:completed|successful|posted)|'
   r'purchase\s+(?:completed|successful|posted))\b|'
   r'\b(?:salary\s+(?:deposit|credited|payment)|cash\s+deposit|'
   r'deposit(?:ed)?|refund\s+received|funds\s+received|'
   r'(?:credit|debit)\s+transfer|account\s+credited)\b|'
   r'(?:تم|تمت)\s+(?:خصم|سحب|إيداع|ايداع|تحويل|ارسال|إرسال|استلام)(?:\s|[:،.,]|$)|'
   r'حوال[ةه]\s+(?:(?:محلي[ةه]|دولي[ةه]|مالي[ةه])\s+)?(?:صادر[ةه]|وارد[ةه])|'
   r'تحويل\s+(?:بنكي\s+)?(?:صادر|وارد)|'
   r'(?:إيداع|ايداع)\s+(?:راتب|مالي)|'
   r'خصم\s+(?:من\s+(?:الحساب|البطاقة)|مبلغ|بقيمة)',
   caseSensitive:false,
  ).hasMatch(body);
  if(posted)return true;
  // A rejected/pending purchase is not evidence that money moved.
  if(facts.pending)return false;
  // A bank purchase headline with a numeric amount remains REVIEW, even if
  // the same SMS also says "OTP", "special offer" or "card activated".
  if(RegExp(r'\b(?:card\s+purchase|online\s+purchase|'
   r'purchase\s+card)\b',caseSensitive:false).hasMatch(body)&&
   RegExp(r'\d+(?:[.,]\d+)?').hasMatch(body))return true;
  // Explicit bank income/expense + a real posted currency amount is not a
  // discount coupon or a reminder. This also protects salary/credit notices
  // that lack the English "debited/credited" verb.
  if(!facts.pending&&
     (facts.kind==WaffraBankOperationKind.income||
      facts.kind==WaffraBankOperationKind.expense||
      facts.kind==WaffraBankOperationKind.cardSettlement)&&
     RegExp(r'(?:\bSAR\b|ريال|ر\.?\s*س)',caseSensitive:false)
      .hasMatch(body)&&
     RegExp(r'[0-9٠-٩]').hasMatch(body))return true;
  // Bank-facts transfer evidence outweighs any unrelated promo/OTP phrase.
  return facts.kind==WaffraBankOperationKind.transfer;
 }

 /// Transfers cannot create ledger income/expense entries; exclude rules
 /// only operate on unconfirmed, non-financial messages.
 static WaffraSmsLocalRule? resolveSpecial({
  required String body,required String sender,
  required WaffraBankOperationKind bankKind,
  Iterable<WaffraSmsLocalRule> custom=const <WaffraSmsLocalRule>[],
 }) {
  final posted=_hasPostedMoneyEvidence(body);
  // Custom exclusions remain conservative and owner-confirmed; curated ready
  // exclusions may safely override a naive "expense" direction based ONLY
  // on words like "خصم حصري" / "payment reminder", not a posted debit.
  final eligible=<WaffraSmsLocalRule>[
   ...custom.where((rule)=>rule.resolvedKind!='excluded'||
    !_hasCompletedFinanceCue(body)),
   ...waffraSaudiSpecialSeedRules,
  ].where((rule)=>
   ((rule.resolvedKind=='transfer'&&bankKind==WaffraBankOperationKind.transfer)||
    (rule.resolvedKind=='excluded'&&!posted&&
     (bankKind==WaffraBankOperationKind.uncertain||
      (rule.builtIn&&rule.id.startsWith('sa_excluded_')))))&&
   matches(rule,body,sender:sender)).toList(growable:false);
  if(eligible.isEmpty)return null;
  if(eligible.map((r)=>r.resolvedKind).toSet().length>1)return null;
  return eligible.first;
 }


 /// Keep a single safe auto-learned bucket per direction and sender while
 /// retaining the exact category learned for each distinct keyword. An
 /// ambiguous message matches no category, never an arbitrary first one.
 static WaffraSmsLocalRule? _withMatchedCategory(
  WaffraSmsLocalRule rule,String body,String sender){
  if(rule.keywordCategories.isEmpty)return rule;
  final selected=<String>{};
  for(final word in rule.keywords){
   final one=WaffraSmsLocalRule(
    id:rule.id,name:rule.name,keywords:[word],income:rule.income,
    category:rule.category,kind:rule.resolvedKind,sender:rule.sender,
    matchAll:false);
   if(matches(one,body,sender:sender)){
    final category=rule.keywordCategories[normalized(word)];
    if(category==null||category.trim().isEmpty)return null;
    selected.add(category);
   }
  }
  if(selected.length!=1)return null;
  return WaffraSmsLocalRule(
   id:rule.id,name:rule.name,keywords:rule.keywords,income:rule.income,
   category:selected.single,kind:rule.resolvedKind,
   sender:rule.sender,matchAll:rule.matchAll,builtIn:rule.builtIn,
   autoPost:rule.autoPost,accountId:rule.accountId,
   accountSuffix:rule.accountSuffix,keywordCategories:rule.keywordCategories);
 }

 static WaffraSmsLocalRule? resolve({
  required String body,required String sender,
  required WaffraBankOperationKind bankKind,
  Iterable<WaffraSmsLocalRule> custom=const <WaffraSmsLocalRule>[],
 }) {
  // Financial direction is independent bank evidence, never an editable rule.
  // All transfers, card settlements, unconfirmed and uncertain SMS need review.
  if(bankKind!=WaffraBankOperationKind.income&&
     bankKind!=WaffraBankOperationKind.expense)return null;
  final income=bankKind==WaffraBankOperationKind.income;
  final personal=custom.where((rule)=>!rule.builtIn&&rule.financial&&
    matches(rule,body,sender:sender)).toList(growable:false);
  if(personal.isNotEmpty){
   if(personal.any((rule)=>rule.income!=income))return null;
   final resolved=personal.map((rule)=>
    _withMatchedCategory(rule,body,sender)).toList(growable:false);
   if(resolved.any((rule)=>rule==null))return null;
   if(resolved.map((rule)=>rule!.category).toSet().length!=1)return null;
   return resolved.first;
  }
  // "Declined purchase", pending authorizations and OTP challenges
  // are NOT settled transactions, even if they mention a familiar merchant.
  if(WaffraBankSmsFactsParser.parse(body).pending)return null;
  final eligible=builtIn.where((rule)=>rule.income==income&&
    matches(rule,body,sender:sender)).toList(growable:false);
  if(eligible.isEmpty)return null;
  // High-specificity merchant/service hints beat fallback banking verbs;
  // conflicting specific categories require explicit user review.
  final specific=eligible.where((r)=>!const <String>{
   'builtin_purchase','builtin_payment','builtin_received','builtin_deposit',
  }.contains(r.id)).toList(growable:false);
  if(specific.map((r)=>r.category).toSet().length>1)return null;
  return specific.isNotEmpty?specific.first:eligible.first;
 }

 static const builtIn=<WaffraSmsLocalRule>[
  WaffraSmsLocalRule(id:'builtin_salary_ar',name:'راتب وارد',keywords:['راتب'],income:true,category:'راتب / راتب أساسي',matchAll:false,builtIn:true),
  WaffraSmsLocalRule(id:'builtin_salary_en',name:'Salary / Payroll',keywords:['salary','payroll'],income:true,category:'راتب / راتب أساسي',matchAll:false,builtIn:true),
  WaffraSmsLocalRule(id:'builtin_refund',name:'استرداد مبلغ',keywords:['refund','reversal','استرداد','استرجاع'],income:true,category:'مبالغ مستردة / استرجاع مشتريات',matchAll:false,builtIn:true),
  WaffraSmsLocalRule(id:'builtin_received',name:'حوالة واردة',keywords:['حوالة واردة','تحويل وارد','credited','received'],income:true,category:'حوالات واردة / حوالة محلية',matchAll:false,builtIn:true),
  WaffraSmsLocalRule(id:'builtin_deposit',name:'إيداع مالي',keywords:['إيداع','ايداع','deposit'],income:true,category:'دخل آخر / دخل غير مصنف',matchAll:false,builtIn:true),
  WaffraSmsLocalRule(id:'builtin_groceries',name:'بقالة وتموين',keywords:['بنده','panda','العثيم','othaim','lulu','التميمي','tamimi','danube','الدانوب'],income:false,category:'بقالة وتموين / سوبرماركت',matchAll:false,builtIn:true),
  WaffraSmsLocalRule(id:'builtin_restaurant',name:'مطاعم ووجبات',keywords:['restaurant','مطعم','البيك','albaik','kfc','ماكدونالدز','mcdonalds'],income:false,category:'مطاعم وكافيهات / مطاعم شعبية',matchAll:false,builtIn:true),
  WaffraSmsLocalRule(id:'builtin_coffee',name:'قهوة وكافيهات',keywords:['coffee','cafe','قهوة','كافيه','ستاربكس','starbucks'],income:false,category:'مطاعم وكافيهات / مقاهي',matchAll:false,builtIn:true),
  WaffraSmsLocalRule(id:'builtin_fuel',name:'بنزين ووقود',keywords:['وقود','بنزين','fuel','petromin'],income:false,category:'السيارة / بنزين ووقود',matchAll:false,builtIn:true),
  WaffraSmsLocalRule(id:'builtin_taxi',name:'مواصلات',keywords:['uber','careem','اوبر','كريم','taxi'],income:false,category:'مواصلات / أوبر وكريم',matchAll:false,builtIn:true),
  WaffraSmsLocalRule(id:'builtin_mobile',name:'فاتورة جوال',keywords:['فاتورة جوال','mobile bill','stc bill','mobily bill','شحن الجوال','شحن جوال'],income:false,category:'فواتير / جوال',matchAll:false,builtIn:true),
  WaffraSmsLocalRule(id:'builtin_pharmacy',name:'صيدلية وأدوية',keywords:['صيدلية','pharmacy','النهدي','nahdi'],income:false,category:'صحة / صيدلية وأدوية',matchAll:false,builtIn:true),
  WaffraSmsLocalRule(id:'builtin_rent',name:'إيجار',keywords:['ايجار','إيجار','rent'],income:false,category:'سكن / إيجار شهري',matchAll:false,builtIn:true),
  WaffraSmsLocalRule(id:'builtin_subscription',name:'اشتراكات رقمية',keywords:['netflix','نتفليكس','spotify','سبوتيفاي'],income:false,category:'اشتراكات رقمية / بث أفلام',matchAll:false,builtIn:true),
  WaffraSmsLocalRule(id:'builtin_purchase',name:'مشتريات عامة',keywords:['شراء','purchase','pos'],income:false,category:'أخرى / مصروف غير مصنف',matchAll:false,builtIn:true),
  WaffraSmsLocalRule(id:'builtin_payment',name:'مدفوعات عامة',keywords:['خصم','debited','payment','دفع'],income:false,category:'أخرى / مصروف غير مصنف',matchAll:false,builtIn:true),
  ...waffraSaudiFinancialSeedRules,
 ];
 // Built-in income, expense, transfer and excluded hints used by the rules
 // UI. Personal secure-store rules remain separate and owner-scoped.
 static const allDefaultRules=<WaffraSmsLocalRule>[
  ...builtIn,...waffraSaudiSpecialSeedRules,
 ];

 static List<String> suggestions(Iterable<String> messages){
  final choices=<String>{};
  final known=<String>{
   'رمز التحقق','رمز التفعيل','رمز الدخول','verification code',
   'security code','one time code','otp',
   // Populate editable quick suggestions from the original small baseline
   // only: 793 immutable Saudi seed phrases are already available in their
   // own searchable/read-only buckets. Rechecking each one for 100 SMS would
   // multiply UI-thread work on first opening the rules editor.
   for(final rule in builtIn.where((r)=>!r.id.startsWith('sa_')))
    for(final term in rule.keywords)term,
   'حوالة صادرة','تحويل صادر','incoming','outgoing',
   'credited','debited','شراء','راتب',
  };
  for(final raw in messages.take(100)){
   final norm=normalized(raw);
   if(WaffraBankSmsFactsParser.parse(raw).kind==WaffraBankOperationKind.expense){
    final merchant=waffraMerchantName(raw,income:false);
    if(merchant!=null&&safeKeyword(merchant))choices.add(merchant);
   }
   for(final term in known){
    if(safeRuleKeyword(term,'excluded')&&norm.contains(normalized(term)))choices.add(term);
   }
  }
  return (choices.toList()..sort((a,b)=>a.compareTo(b))).take(100).toList();
 }

 /// Make a conservative, sender-scoped draft from a reviewed bank message.
 /// Only established classification phrases can be learned automatically;
 /// the rule is never permission to record money or change an account.
 static WaffraSmsLocalRule? suggestedRule({
  required String body,required String sender,required String kind,
  String category='',bool confidentOnly=false,
 }) {
  if(sender.trim().isEmpty||sender.length>64||
     (confidentOnly&&sender.trim().length<3)||
     !const <String>{'income','expense','transfer','excluded'}
      .contains(kind))return null;
  final facts=WaffraBankSmsFactsParser.parse(body);
  final isIncome=kind=='income',isExpense=kind=='expense';
  if((isIncome||isExpense)&&
     (facts.pending||facts.kind!=(isIncome?
      WaffraBankOperationKind.income:WaffraBankOperationKind.expense)))
   return null;
  if(kind=='excluded'&&
     (facts.kind!=WaffraBankOperationKind.uncertain||
      (WaffraBankSmsFactsParser.isVerificationChallenge(body)&&
       _hasCompletedFinanceCue(body))))return null;
  if(kind=='transfer'&&facts.kind!=WaffraBankOperationKind.transfer)
   return null;
  if((isIncome||isExpense)&&(
   category.trim().isEmpty||normalized(category).contains('غير مصنف')||
   normalized(category).contains('غير محدد')||
   normalized(category).contains('uncategorized')))return null;
  final normalizedBody=normalized(body);
  if(kind=='excluded'){
   final family=_excludedStructuralTemplate(body:body,sender:sender);
   if(family!=null&&matches(family,body,sender:sender))return family;
  }
  final safe=<String>[];
  if(kind=='excluded'){
   for(final term in const <String>[
    'رمز التفعيل','رمز التحقق','رمز الدخول','verification code',
    'security code','one time code','otp',
   ]){
    if(safeRuleKeyword(term,kind)&&
       normalizedBody.contains(normalized(term)))safe.add(term);
   }
  }else if(kind=='transfer'){
   for(final term in const <String>['حوالة صادرة','حوالة واردة',
    'تحويل صادر','تحويل وارد','transfer']){
    if(safeRuleKeyword(term,kind)&&
       normalizedBody.contains(normalized(term)))safe.add(term);
   }
  }else{
   // A generic purchase/payment keyword is not a safe learned merchant rule.
   final merchant=waffraMerchantName(body,income:isIncome);
   if(merchant!=null&&safeKeyword(merchant)&&
      normalizedBody.contains(normalized(merchant)))safe.add(merchant);
   for(final known in builtIn.where((r)=>
    r.income==isIncome&&r.category==category&&
    r.id!='builtin_purchase'&&r.id!='builtin_payment'&&
    matches(r,body,sender:sender))){
    for(final term in known.keywords){
     if(safeRuleKeyword(term,kind)&&
        normalizedBody.contains(normalized(term)))safe.add(term);
    }
   }
  }
  if(safe.isEmpty)return null;
  final names=<String,String>{
   'income':'دخل معروف','expense':'مصروف معروف',
   'transfer':'تحويل بنكي','excluded':'رسائل تحقق',
  };
  final rule=WaffraSmsLocalRule(
   id:'smart_${sha256.convert(utf8.encode(
    '${normalized(sender)}|$kind|${normalized(safe.first)}')).toString().substring(0,32)}',
   name:names[kind]!,kind:kind,income:isIncome,
   category:(isIncome||isExpense)?category:'',
   sender:sender.trim(),keywords:safe.toSet().take(6).toList(),
   matchAll:true,autoPost:false,
   contextFragments:_safeContextFragments(body),
  );
  try{
   validate(rule);
   // Never store a proposal which does not match the exact reviewed SMS.
   if(!matches(rule,body,sender:sender))return null;
   return rule;
  }on FormatException{return null;}
 }

 /// Conservative, sender-agnostic keyword hints from a confirmed
 /// transaction description. Manual and user-reviewed SMS use this SAME
 /// extractor. Never retain amounts, account suffixes, secrets or identifiers.
 /// Hints can only suggest categories for later bank review, never post money.
 static List<String> safeDescriptionKeywords(String description){
  final normalizedText=normalized(description);
  if(normalizedText.isEmpty||normalizedText.length>160)return const [];
  // Avoid retaining a sensitive description with secret/account terms.
  if(RegExp(r'iban|otp|pin|password|رقم الحساب|رمز التحقق|رمز التفعيل|'
    r'كلمة المرور|بطاقة مصرفية',caseSensitive:false).hasMatch(normalizedText)){
   return const [];
  }
  const generic=<String>{
   'دخل','مصروف','حواله','تحويل','سداد','دفع','خصم','شراء',
   'تم','من','الى','علي','في','بواسطه','عبر','عن','لدي',
   'مبلغ','ريال','رس','العمليه','عمليه','رصيد','حساب',
   'شحن','اعاده','تجديد','مدفوعات','مشتريات','مستحق',
   'income','expense','payment','purchase','pos','debit',
   'credit','amount','sar','from','to','the','for','and',
   'transfer','paid','received','topup','recharge',
  };
  final words=<String>[];
  for(final item in normalizedText.split(RegExp(r'[^a-z\u0621-\u064a]+',
   caseSensitive:false))){
   if(item.length<4||generic.contains(item)||!safeKeyword(item))continue;
   if(!words.contains(item))words.add(item);
   if(words.length>=6)break;
  }
  if(words.isEmpty)return const [];
  final candidates=<String>[];
  // Exact safe description helps deterministic repeated merchant phrases.
  if(normalizedText.length<=36&&safeKeyword(description)&&
     !generic.contains(normalizedText))candidates.add(description.trim());
  // Two distinctive tokens support reordered words in a later SMS.
  if(words.length>=2){
   final phrase=words.take(2).join(' ');
   if(safeKeyword(phrase)&&!candidates.any(
      (p)=>normalized(p)==normalized(phrase)))candidates.add(phrase);
  }
  // Distinctive words enable reviewed suggestions for a similar SMS with
  // extra intervening terms, not a bank account or auto-posting permission.
  for(final word in words){
   if(candidates.any((p)=>normalized(p)==word))continue;
   candidates.add(word);
   if(candidates.length>=4)break;
  }
  return List<String>.unmodifiable(candidates.take(4));
 }

 /// A manual OR reviewed-SMS transaction teaches a safe description/category
 /// preference in a shared non-posting bucket. It cannot invent a bank sender,
 /// account suffix, SMS amount or finance-account assignment.
 static WaffraSmsLocalRule? manualCategoryPattern({
  required String description,required String category,required bool income,
 }) {
  if(category.trim().isEmpty||normalized(category).contains('غير مصنف')||
     normalized(category).contains('غير محدد'))return null;
  final keywords=safeDescriptionKeywords(description);
  if(keywords.isEmpty)return null;
  final kind=income?'income':'expense';
  final id='manual_${sha256.convert(utf8.encode(
   '$kind|${normalized(description)}|${normalized(category)}')).toString().substring(0,32)}';
  final rule=WaffraSmsLocalRule(
   id:id,name:description.trim().length<=60?description.trim():keywords.first,
   kind:kind,income:income,
   category:category.trim(),keywords:keywords,
   sender:'',matchAll:false,autoPost:false,
  );
  try{validate(rule);return rule;}on FormatException{return null;}
 }

 /// A manual account transfer teaches safe bilingual classification hints;
 /// it cannot post bank SMS or silently choose either account.
 static WaffraSmsLocalRule manualTransferPattern(){
  const rule=WaffraSmsLocalRule(
   id:'manual_transfer_account_to_account',
   name:'تحويل بين حساباتي',kind:'transfer',income:false,
   category:'',keywords:['تحويل','transfer'],sender:'',
   matchAll:false,autoPost:false);
  validate(rule);
  return rule;
 }

 /// Automatic learning is a classification preference, never a ledger
 /// permission. Keep one reusable sender/category pattern rather than
 /// creating a new user-visible rule after every reviewed SMS.
 ///
 /// An explicitly enabled autoPost rule is immutable here: appending a new
 /// keyword to it would silently broaden the owner's spending authority.

 /// Add a confirmed keyword to its existing system bucket, not a new rule.
 /// Keep sender identity and per-phrase category intact. A user-created rule
 /// or a rule with explicit posting permission is NEVER widened silently.
 static List<WaffraSmsLocalRule> upsertLearned({
  required List<WaffraSmsLocalRule> existing,
  required WaffraSmsLocalRule candidate,
 }) {
  validate(candidate);
  if(candidate.autoPost||candidate.id.startsWith('custom_')){
   throw const FormatException('Learning cannot grant posting permission');
  }
  // A phrase already assigned to a different category is ambiguous.
  // Do not duplicate it, overwrite the owner, or teach a wrong category.
  if(existing.any((rule)=>rule.resolvedKind==candidate.resolvedKind&&
    normalized(rule.sender)==normalized(candidate.sender)&&
    rule.keywords.any((word)=>candidate.keywords.any((other)=>
     normalized(word)==normalized(other)&&
     (rule.keywordCategories[normalized(word)]??rule.category)!=
      candidate.category)))){
   return existing;
  }
  // An existing explicit auto-post pattern must not be expanded or cloned.
  if(existing.any((rule)=>rule.autoPost&&
   rule.resolvedKind==candidate.resolvedKind&&
   normalized(rule.sender)==normalized(candidate.sender)&&
   rule.category==candidate.category&&
   rule.keywords.any((word)=>candidate.keywords.any(
    (other)=>normalized(word)==normalized(other))))){
   return existing;
  }
  final index=candidate.matchAll?-1:existing.indexWhere((rule)=>
   !rule.autoPost&&!rule.matchAll&&
   (rule.id.startsWith('smart_')||rule.id.startsWith('manual_'))&&
   rule.resolvedKind==candidate.resolvedKind&&
   normalized(rule.sender)==normalized(candidate.sender)&&
   rule.accountId==candidate.accountId);
  if(index<0){
   if(existing.any((r)=>r.id==candidate.id))return existing;
   if(existing.length>=100)return existing;
   return List<WaffraSmsLocalRule>.unmodifiable([...existing,candidate]);
  }
  final current=existing[index];
  final combined=<String>{...current.keywords,...candidate.keywords};
  if(combined.length>12)return existing;
  if(combined.length==current.keywords.length)return existing;
  final mapped=<String,String>{
   for(final word in current.keywords)
    normalized(word):current.keywordCategories[normalized(word)]??current.category,
   for(final word in candidate.keywords)
    normalized(word):candidate.keywordCategories[normalized(word)]??candidate.category,
  };
  final updated=WaffraSmsLocalRule(
   id:current.id,name:current.name,kind:current.resolvedKind,
   keywords:combined.toList(),income:current.income,
   category:current.category,sender:current.sender,
   matchAll:false,autoPost:false,
   accountId:current.accountId,accountSuffix:current.accountSuffix,
   keywordCategories:current.financial?mapped:const <String,String>{},
  );
  validate(updated);
  return List<WaffraSmsLocalRule>.unmodifiable([
   for(var i=0;i<existing.length;i++)i==index?updated:existing[i]
  ]);
 }

 static void validate(WaffraSmsLocalRule rule){
  if(rule.builtIn||rule.id.trim().isEmpty||rule.id.length>80||
     !const <String>{'income','expense','transfer','excluded'}
      .contains(rule.resolvedKind)||
     (rule.resolvedKind=='income'&&!rule.income)||
     (rule.resolvedKind!='income'&&rule.income)||
     rule.name.trim().length<2||rule.name.trim().length>60||
     rule.keywords.isEmpty||rule.keywords.length>12||
     rule.keywords.any((s)=>!safeRuleKeyword(s,rule.resolvedKind))||
     (rule.financial&&rule.category.trim().isEmpty)||
     rule.category.length>130||rule.sender.length>64||
     rule.keywordCategories.length>rule.keywords.length||
     (rule.keywordCategories.isNotEmpty&&
      (!rule.financial||rule.autoPost||
       rule.keywordCategories.length!=rule.keywords.map(normalized).toSet().length||
       rule.keywordCategories.entries.any((e)=>
        !rule.keywords.any((word)=>normalized(word)==e.key)||
        e.value.trim().isEmpty||e.value.length>130)))||
     rule.contextFragments.length>12||
     rule.contextFragments.any((p)=>!safeRuleKeyword(p,rule.resolvedKind))||
     (rule.templateFamily.isNotEmpty&&
      (!rule.id.startsWith('template_')||rule.resolvedKind!='excluded'||
       rule.sender.trim().isEmpty||!rule.matchAll||rule.autoPost||
       !const {'verification','beneficiary_management'}
        .contains(rule.templateFamily)))||
     rule.accountId.length>128||
     (rule.accountSuffix.isNotEmpty&&
      !RegExp(r'^[0-9]{4}$').hasMatch(rule.accountSuffix))||
     (rule.autoPost&&(!rule.financial||rule.accountId.trim().isEmpty||
      rule.sender.trim().isEmpty||rule.accountSuffix.length!=4))) {
   throw const FormatException('Invalid local SMS rule');
  }
 }
}

/// Per-user encrypted app configuration, not a new unverified finance writer.
/// No source SMS or transaction amount is ever persisted here.
class WaffraSmsLocalRuleStore {
 const WaffraSmsLocalRuleStore();
 static const _storage=FlutterSecureStorage(
  aOptions:AndroidOptions(encryptedSharedPreferences:true));

 static String ownerKey({required String provider,
  required String phone,required String email}){
  final identity=email.trim().isNotEmpty?
   'email:${email.trim().toLowerCase()}':
   phone.trim().isNotEmpty?'phone:${phone.trim()}':'';
  if(identity.isEmpty)return '';
  return sha256.convert(utf8.encode(identity)).toString();
 }
 String _key(String owner) {
  if(!RegExp(r'^[a-f0-9]{64}$').hasMatch(owner)){
   throw const FormatException('Verified SMS rules owner missing');
  }
  return 'waffra_sms_local_rules_v1_$owner';
 }
 Future<List<WaffraSmsLocalRule>> read(String owner) async {
  final raw=await _storage.read(key:_key(owner));
  if(raw==null||raw.isEmpty)return const [];
  final values=jsonDecode(raw);
  if(values is! List)throw const FormatException('Invalid local rules store');
  final rules=<WaffraSmsLocalRule>[];
  for(final value in values){
   if(value is! Map)throw const FormatException('Invalid rule record');
   final rule=WaffraSmsLocalRule.fromJson(Map<String,dynamic>.from(value));
   WaffraSmsLocalRules.validate(rule);
   rules.add(rule);
  }
  if(rules.length>100||rules.map((e)=>e.id).toSet().length!=rules.length){
   throw const FormatException('Local rule store failed validation');
  }
  return rules;
 }
 Future<void> write(String owner,List<WaffraSmsLocalRule> rules)async{
  if(rules.length>100||rules.map((e)=>e.id).toSet().length!=rules.length){
   throw const FormatException('Too many or duplicate rules');
  }
  for(final rule in rules)WaffraSmsLocalRules.validate(rule);
  await _storage.write(key:_key(owner),
   value:jsonEncode(rules.map((rule)=>rule.toJson()).toList(growable:false)));
 }
}
