import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'waffra_bank_sms_facts.dart';
import 'waffra_merchant_rules.dart';

/// Local-only, user-reviewable SMS classification. Rules are suggestions:
/// neither this file nor the settings screen can post money or link an account.
class WaffraSmsLocalRule {
 const WaffraSmsLocalRule({
  required this.id,required this.name,required this.keywords,
  required this.income,required this.category,
  this.matchAll=true,this.sender='',this.builtIn=false,
  this.kind='',this.autoPost=false,this.accountId='',this.accountSuffix='',
 });
 final String id,name,category,sender;
 final List<String> keywords;
 final bool income,matchAll,builtIn,autoPost;
 final String kind,accountId,accountSuffix;
 String get resolvedKind=>kind.isEmpty?(income?'income':'expense'):kind;
 bool get financial=>resolvedKind=='income'||resolvedKind=='expense';

 Map<String,Object?> toJson()=>{
  'id':id,'name':name,'keywords':keywords,'income':income,
  'category':category,'matchAll':matchAll,'sender':sender,
  'kind':resolvedKind,'autoPost':autoPost,'accountId':accountId,
  'accountSuffix':accountSuffix,
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

 static bool matches(WaffraSmsLocalRule rule,String body,{String sender=''}) {
  if(rule.keywords.isEmpty||rule.keywords.any((word)=>
    !safeRuleKeyword(word,rule.resolvedKind)))return false;
  if(rule.sender.isNotEmpty&&normalized(rule.sender)!=normalized(sender))return false;
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

 /// Transfers cannot create ledger income/expense entries; exclude rules
 /// only operate on unconfirmed, non-financial messages.
 static WaffraSmsLocalRule? resolveSpecial({
  required String body,required String sender,
  required WaffraBankOperationKind bankKind,
  Iterable<WaffraSmsLocalRule> custom=const <WaffraSmsLocalRule>[],
 }) {
  final eligible=custom.where((rule)=>
   ((rule.resolvedKind=='transfer'&&bankKind==WaffraBankOperationKind.transfer)||
    (rule.resolvedKind=='excluded'&&bankKind==WaffraBankOperationKind.uncertain))&&
   matches(rule,body,sender:sender)).toList(growable:false);
  if(eligible.isEmpty)return null;
  if(eligible.map((r)=>r.resolvedKind).toSet().length>1)return null;
  return eligible.first;
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
   // A rule that contradicts the verified bank direction must never win.
   if(personal.any((rule)=>rule.income!=income))return null;
   final categories=personal.map((rule)=>rule.category).toSet();
   if(categories.length!=1)return null;
   return personal.first;
  }
  final eligible=builtIn.where((rule)=>rule.income==income&&
    matches(rule,body,sender:sender)).toList(growable:false);
  if(eligible.isEmpty)return null;
  // Explicit service/merchant rules first, generic transaction words last.
  return eligible.first;
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
  WaffraSmsLocalRule(id:'builtin_mobile',name:'فاتورة جوال',keywords:['فاتورة جوال','mobile bill','stc bill','mobily bill'],income:false,category:'فواتير / جوال',matchAll:false,builtIn:true),
  WaffraSmsLocalRule(id:'builtin_pharmacy',name:'صيدلية وأدوية',keywords:['صيدلية','pharmacy','النهدي','nahdi'],income:false,category:'صحة / صيدلية وأدوية',matchAll:false,builtIn:true),
  WaffraSmsLocalRule(id:'builtin_rent',name:'إيجار',keywords:['ايجار','إيجار','rent'],income:false,category:'سكن / إيجار شهري',matchAll:false,builtIn:true),
  WaffraSmsLocalRule(id:'builtin_subscription',name:'اشتراكات رقمية',keywords:['netflix','نتفليكس','spotify','سبوتيفاي'],income:false,category:'اشتراكات رقمية / بث أفلام',matchAll:false,builtIn:true),
  WaffraSmsLocalRule(id:'builtin_purchase',name:'مشتريات عامة',keywords:['شراء','purchase','pos'],income:false,category:'أخرى / مصروف غير مصنف',matchAll:false,builtIn:true),
  WaffraSmsLocalRule(id:'builtin_payment',name:'مدفوعات عامة',keywords:['خصم','debited','payment','دفع'],income:false,category:'أخرى / مصروف غير مصنف',matchAll:false,builtIn:true),
 ];

 static List<String> suggestions(Iterable<String> messages){
  final choices=<String>{};
  final known=<String>{
   'رمز التحقق','رمز التفعيل','رمز الدخول','verification code',
   'security code','one time code','otp',
   for(final rule in builtIn)
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
  if(kind=='excluded'&&facts.kind!=WaffraBankOperationKind.uncertain)
   return null;
  if(kind=='transfer'&&facts.kind!=WaffraBankOperationKind.transfer)
   return null;
  final normalizedBody=normalized(body);
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
   matchAll:false,autoPost:false,
  );
  try{
   validate(rule);
   // Never store a proposal which does not match the exact reviewed SMS.
   if(!matches(rule,body,sender:sender))return null;
   return rule;
  }on FormatException{return null;}
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
