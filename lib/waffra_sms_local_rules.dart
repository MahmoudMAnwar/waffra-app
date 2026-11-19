import 'dart:convert';
import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'waffra_bank_sms_facts.dart';
import 'waffra_merchant_rules.dart';

part 'waffra_sms_saudi_seed_rules.part.dart';

/// Human-readable, non-sensitive explanation for a missing learned rule.
String waffraExclusionLearningReason(String? reason,{bool english=false}){
 if(english)return switch(reason){
  'financial_operation'=>'Financial SMS: only this message was excluded; similar payments will remain visible.',
  'unsupported_template'=>'No safe reusable pattern was identified in this message.',
  'owner_unavailable'=>'Signed-in owner verification is required before saving a rule.',
  'sender_unverified'=>'The sender cannot be verified for a reusable rule.',
  'conflicting_rules'=>'An existing rule conflicts with this proposed exclusion.',
  'rule_capacity'=>'Rule storage is full.',
  'rule_storage_unavailable'=>'The encrypted rule could not be saved or read back.',
  'post_save_verification_failed'=>'The rule could not be verified after saving.',
  _=>'A reusable exclusion rule was not confirmed.',
 };
 return switch(reason){
  'financial_operation'=>'دي حركة مالية؛ استبعدنا الرسالة دي فقط حتى لا نخفي مشتريات أو حوالات مشابهة.',
  'unsupported_template'=>'مفيش نمط استبعاد آمن يمكن تعميمه من نص الرسالة دي.',
  'owner_unavailable'=>'لازم التحقق من صاحب الحساب قبل حفظ قاعدة جديدة.',
  'sender_unverified'=>'مرسل الرسالة مش مؤكد لإنشاء قاعدة قابلة لإعادة الاستخدام.',
  'conflicting_rules'=>'في قاعدة محفوظة متعارضة مع الاستبعاد المقترح.',
  'rule_capacity'=>'وصلت للحد الأقصى للقواعد؛ احذف قاعدة غير مستخدمة أولًا.',
  'rule_storage_unavailable'=>'تعذر حفظ القاعدة المشفرة أو قراءتها للتحقق من نجاح الحفظ.',
  'post_save_verification_failed'=>'القاعدة لم تظهر بعد إعادة قراءة القواعد المحفوظة.',
  _=>'لم يتم تأكيد حفظ قاعدة استبعاد للرسائل المشابهة.',
 };
}

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

/// M986: compact conservative candidate index for four-kind SMS review.
/// All rules stay ordered exactly as before (custom first, then defaults).
/// Prefix pruning only removes rules whose normalized keywords are absent.
/// Structured/verification templates bypass keyword pruning entirely.
class WaffraSmsRuleCandidateIndex {
 WaffraSmsRuleCandidateIndex(Iterable<WaffraSmsLocalRule> custom){
  final all=<WaffraSmsLocalRule>[
   ...custom,...WaffraSmsLocalRules.allDefaultRules,
  ];
  for(var i=0;i<all.length;i++){
   final rule=all[i];
   final key=WaffraSmsLocalRules.normalized(rule.sender);
   final entry=MapEntry<int,WaffraSmsLocalRule>(i,rule);
   _senderByIndex[i]=key;
   final tokens=<String>{};
   if(rule.templateFamily.isNotEmpty||rule.keywords.isEmpty){
    _always.add(entry);
    continue;
   }
   for(final word in rule.keywords){
    final norm=WaffraSmsLocalRules.normalized(word);
    if(norm.length<2){
     _always.add(entry);
     continue;
    }
    tokens.add(norm.substring(0,2));
   }
   for(final token in tokens){
    _prefix.putIfAbsent(token,()=>[]).add(entry);
   }
  }
 }
 final Map<String,List<MapEntry<int,WaffraSmsLocalRule>>> _prefix={};
 final List<MapEntry<int,WaffraSmsLocalRule>> _always=[];
 final Map<int,String> _senderByIndex={};
 List<WaffraSmsLocalRule> candidates({
  required String body,required String sender,
 }){
  final senderKey=WaffraSmsLocalRules.normalized(sender);
  final norm=WaffraSmsLocalRules.normalized(body);
  final picked=<int,WaffraSmsLocalRule>{};
  void add(MapEntry<int,WaffraSmsLocalRule> item){
   final scoped=_senderByIndex[item.key]??'';
   if(scoped.isNotEmpty&&scoped!=senderKey)return;
   picked[item.key]=item.value;
  }
  for(final rule in _always)add(rule);
  final seen=<String>{};
  for(var i=0;i+1<norm.length;i++){
   final prefix=norm.substring(i,i+2);
   if(!seen.add(prefix))continue;
   for(final rule in _prefix[prefix]??const <MapEntry<int,WaffraSmsLocalRule>>[]){
    add(rule);
   }
  }
  final ordered=picked.keys.toList()..sort();
  return List<WaffraSmsLocalRule>.unmodifiable([
   for(final id in ordered)picked[id]!,
  ]);
 }
}

/// Approved keywords only. Never suggest bank identifiers, long numbers,
/// statement balances, OTPs, account/card suffixes or unredacted SMS bodies.
abstract final class WaffraSmsLocalRules {
 // M1032 #751: bounded, backwards-compatible V1 owner-secure rule capacity.
 // Existing 100-rule archives remain readable; no AutoPost grants are inferred.
 static const int maxStoredRules=256;

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
  (kind=='excluded'&&const <String>{
   'otp','pin','تفعيل الحساب'
  }.contains(normalized(text)));

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

 // Bank operation types describe direction, not a merchant/category identity.
 // Never learn or replay a category from only this shared SMS heading.
 static bool _genericBankOperationHeading(String word){
  const headings=<String>[
   'حوالة داخلية واردة','حوالة محلية واردة','حوالة دولية واردة',
   'حوالة واردة','credit transfer internal','received transfer',
   'حوالة داخلية صادرة','حوالة محلية صادرة','حوالة دولية صادرة',
   'حوالة صادرة','debit transfer internal','outgoing transfer',
  ];
  final value=normalized(word);
  const generic=<String>{
   'حواله','حوالات','تحويل','تحويلات','داخليه','خارجيه',
   'محليه','دوليه','صادره','وارده','الداخليه','الخارجيه',
   'المحليه','الدوليه','الصادره','الوارده','بنكيه',
   'شراء','عبر','نقاط','البيع','مدي','عمليه','مبلغ',
   'outgoing','incoming','transfer','internal','external',
   'local','international','debit','credit','received','sent',
   'purchase','payment','pos','bank','transaction',
  };
  return headings.any((heading)=>normalized(heading)==value)||
   (value.isNotEmpty&&value.split(' ').every(generic.contains));
 }

 static bool matches(WaffraSmsLocalRule rule,String body,{
  String sender='',String? preNormalizedBody,
 }) {
  final trustedSeed=rule.builtIn&&rule.id.startsWith('sa_');
  if(rule.keywords.isEmpty||rule.keywords.any((word)=>
    trustedSeed?!_safeSaudiSeedKeyword(word,rule.resolvedKind):
    !safeRuleKeyword(word,rule.resolvedKind)))return false;
  if(rule.sender.isNotEmpty&&normalized(rule.sender)!=normalized(sender))return false;
  // A previously learned bank-operation heading cannot carry a merchant
  // category across unrelated notifications (including existing V3 rules).
  if(rule.id.startsWith('smart_')&&rule.financial&&
     rule.keywords.every((word)=>_genericBankOperationHeading(word)))return false;
  if(rule.templateFamily=='verification'){
   return WaffraBankSmsFactsParser.isVerificationChallenge(body)&&
    !_hasCompletedFinanceCue(body);
  }
  if(rule.templateFamily=='beneficiary_management'){
   return _beneficiaryManagement(body)&&!_hasCompletedFinanceCue(body);
  }
  // Legacy manual review hints can contain broad words like "outgoing"
  // or "internal". They must never select a category by those words alone.
  final matchKeywords=rule.financial&&rule.id.startsWith('manual_')?
   rule.keywords.where((word)=>!_genericBankOperationHeading(word))
    .toList(growable:false):rule.keywords;
  if(matchKeywords.isEmpty)return false;
  // M980: same normalization reused by all four rule groups per SMS.
  final source=' ${preNormalizedBody??normalized(body)} ';
  bool has(String keyword){
   final safe=normalized(keyword);
   // M980: avoid full regex work for unmentioned keywords across 4 groups.
   if(safe.isEmpty||!source.contains(safe))return false;
   // Boundaries prevent short English keywords matching arbitrary longer words.
   return source.contains(' $safe ')||
    source.contains(' $safe\n')||
    RegExp('(^|[^a-z\\u0621-\\u064a])${RegExp.escape(safe)}([^a-z\\u0621-\\u064a]|\u0024)')
     .hasMatch(source);
  }
  return rule.matchAll?matchKeywords.every(has):matchKeywords.any(has);
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
   r'(?:credit|debit)\s+transfer|account\s+credited|'
   r'payment\s+received|money\s+received|credit\s+card\s+payment|'
   r'card\s+(?:balance|bill)\s+payment|card\s+settlement)\b|'
   r'(?:تم|تمت)\s+(?:خصم|سحب|إيداع|ايداع|تحويل|ارسال|إرسال|استلام|دفع|سداد|شراء)(?:\s|[:،.,]|$)|'
   r'حوال[ةه]\s+(?:(?:محلي[ةه]|دولي[ةه]|مالي[ةه])\s+)?(?:صادر[ةه]|وارد[ةه])|'
   r'تحويل\s+(?:بنكي\s+)?(?:صادر|وارد)|'
   r'(?:إيداع|ايداع)\s+(?:راتب|مالي)|'
   r'خصم\s+(?:من\s+(?:الحساب|البطاقة)|مبلغ|بقيمة)',
   caseSensitive:false,
  ).hasMatch(body);
  if(posted)return true;
  // An independent bank purchase headline plus actual amount may NOT be
  // hidden by OTP wording. Detect it BEFORE the generic pending check.
  if(RegExp(r'\b(?:card\s+purchase|online\s+purchase|'
   r'purchase\s+card)\b',caseSensitive:false).hasMatch(body)&&
   RegExp(r'[0-9٠-٩]+(?:[.,][0-9٠-٩]+)?').hasMatch(body))return true;
  // An actual Arabic purchase with an explicit SAR amount is a posted
  // movement even if an unrelated OTP phrase marks the combined SMS pending.
  // Marketing discounts / payment reminders have no such purchase evidence.
  if(RegExp(r'(?:^|\s)(?:شراء|عملية\s+شراء)\s+(?:بمبلغ|بقيمة)\s*'
   r'[0-9٠-٩]+(?:[.,][0-9٠-٩]+)?\s*(?:ريال|SAR)',
   caseSensitive:false).hasMatch(body))return true;
  // A failed or still-pending notice alone is not a settled movement.
  if(facts.pending)return false;
  // Explicit bank income/expense + a real posted currency amount is not a
  // discount coupon or a reminder. This also protects salary/credit notices
  // that lack the English "debited/credited" verb.
  if(facts.kind==WaffraBankOperationKind.cardSettlement)return true;
  if(!facts.pending&&
     (facts.kind==WaffraBankOperationKind.income||
      facts.kind==WaffraBankOperationKind.expense)&&
     RegExp(r'(?:\bSAR\b|ريال)',caseSensitive:false)
      .hasMatch(body)&&
     RegExp(r'[0-9٠-٩]').hasMatch(body))return true;
  // Bank-facts transfer evidence outweighs any unrelated promo/OTP phrase.
  return facts.kind==WaffraBankOperationKind.transfer;
 }

 /// Transfers cannot create ledger income/expense entries; exclude rules
 /// only operate on unconfirmed, non-financial messages.
 /// M980: match every SMS against all four owner/default rule groups before
 /// making safety decisions. Matching is only a suggestion, never posting.
 static List<WaffraSmsLocalRule> matchAllFourKinds({
  required String body,required String sender,
  Iterable<WaffraSmsLocalRule> custom=const <WaffraSmsLocalRule>[],
  WaffraSmsRuleCandidateIndex? candidateIndex,
 }){
  final found=<WaffraSmsLocalRule>[];
  final normalizedBody=normalized(body);
  // M1009: a historic generic transfer keyword must not override a
  // definite external SAMA income/expense direction. This also protects
  // legacy saved manual_transfer_account_to_account rules containing
  // merely 'transfer' or 'تحويل' from creating false conflicts.
  final objectiveKind=WaffraBankSmsFactsParser.parse(body).kind;
  final candidates=candidateIndex==null?
   <WaffraSmsLocalRule>[...custom,...allDefaultRules]:
   candidateIndex.candidates(body:body,sender:sender);
  for(final rule in candidates){
   if(!const <String>{'income','expense','transfer','excluded'}
     .contains(rule.resolvedKind))continue;
   if(rule.resolvedKind=='transfer'&&
     (objectiveKind==WaffraBankOperationKind.income||
      objectiveKind==WaffraBankOperationKind.expense))continue;
   if(matches(rule,body,sender:sender,
     preNormalizedBody:normalizedBody))found.add(rule);
  }
  return List<WaffraSmsLocalRule>.unmodifiable(found);
 }

 static WaffraSmsLocalRule? resolveSpecial({
  required String body,required String sender,
  required WaffraBankOperationKind bankKind,
  Iterable<WaffraSmsLocalRule> custom=const <WaffraSmsLocalRule>[],
  bool nativeSensitiveOtp=false,
  Iterable<WaffraSmsLocalRule>? matchedRules,
 }) {
  final posted=_hasPostedMoneyEvidence(body);
  // Android masks OTP digits before encrypted storage. Preserve the native
  // sensitive classification, but never auto-exclude a mixed/posted movement.
  final verification=nativeSensitiveOtp||
   WaffraBankSmsFactsParser.isVerificationChallenge(body);
  final safeVerification=verification&&!posted&&
   !_hasCompletedFinanceCue(body);
  // Evaluate every owner rule and vetted default against every SMS,
  // regardless of a weak preclassification. Inferred bankKind is not proof
  // of a posted debit; completed-money cues are independently checked first.
  // Genuine finance, transfers, and mixed OTP + money always stay in review.
  // The same precomputed candidates cover ALL four types. Only apply safe
  // transfer/exclusion priorities after evaluating every saved/default rule.
  final checked=matchedRules??<WaffraSmsLocalRule>[
   ...custom,...waffraSaudiSpecialSeedRules,
  ];
  final eligible=checked.where((rule)=>
   ((rule.resolvedKind=='transfer'&&bankKind==WaffraBankOperationKind.transfer)||
    (rule.resolvedKind=='excluded'&&!posted&&
     // Preserve the original custom-exclusion guard: generic financial
     // action language requires human review, unlike vetted default seeds.
     (rule.builtIn||!_hasCompletedFinanceCue(body))&&
     !(verification&&_hasCompletedFinanceCue(body))))&&
   (matchedRules!=null||matches(rule,body,sender:sender)))
    .toList(growable:false);
  // Conflicting user rules never silently hide or misclassify an SMS.
  if(matchedRules!=null&&matchedRules.where((r)=>!r.builtIn)
    .map((r)=>r.resolvedKind).toSet().length>1)return null;
  // Unknown new-app verification language is still a known security
  // EVENT, even if none of the older literal seed fragments matched.
  // Reuse the existing seed identity; do not learn/store sensitive OTPs.
  if(eligible.isEmpty&&safeVerification){
   return waffraSaudiSpecialSeedRules.firstWhere(
    (rule)=>rule.id=='sa_excluded_009');
  }
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
  Iterable<WaffraSmsLocalRule>? matchedRules,
 }) {
  // Financial direction is independent bank evidence, never an editable rule.
  // All transfers, card settlements, unconfirmed and uncertain SMS need review.
  if(bankKind!=WaffraBankOperationKind.income&&
     bankKind!=WaffraBankOperationKind.expense)return null;
  // M980: even a fully verified direction never grants autoPost when two
  // saved owner rules disagree about this SAME message's classification.
  if(matchedRules!=null&&matchedRules.where((r)=>!r.builtIn)
    .map((r)=>r.resolvedKind).toSet().length>1)return null;
  final income=bankKind==WaffraBankOperationKind.income;
  final personal=(matchedRules??custom).where((rule)=>
   !rule.builtIn&&rule.financial&&
   (matchedRules!=null||matches(rule,body,sender:sender)))
    .toList(growable:false);
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
  final eligible=(matchedRules??builtIn).where((rule)=>
   rule.builtIn&&rule.financial&&rule.income==income&&
   (matchedRules!=null||matches(rule,body,sender:sender)))
    .toList(growable:false);
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

 /// Why a user-selected one-SMS exclusion cannot become a reusable rule.
 /// A completed financial event is NEVER hidden across different SMS.
 static String? exclusionLearningBlocker({
  required String body,required String sender,
 }){
  if(sender.trim().length<3||sender.trim().length>64)
   return 'sender_unverified';
  final facts=WaffraBankSmsFactsParser.parse(body);
  if(facts.kind!=WaffraBankOperationKind.uncertain||
     _hasCompletedFinanceCue(body)||_hasPostedMoneyEvidence(body))
   return 'financial_operation';
  if(suggestedGlobalRule(body:body,sender:sender,kind:'excluded',
      confidentOnly:true)==null)
   return 'unsupported_template';
  return null;
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
  // Financial category learning must use a distinct merchant/service signal.
  // A SAMA operation heading is shared by unrelated purchases/transfers.
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
  }else if(safe.isEmpty){
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

 /// Learn safe non-posting suggestions for EVERY sender after a committed
 /// owner decision. Previously learned sender-scoped rules are never promoted.
 /// Only a proven verification/beneficiary event can become a global
 /// structural exclusion; merely tapping Exclude never teaches arbitrary text.
 /// M1009: only a user-confirmed exclusion of a recognisable service
 /// announcement can teach text across senders. Never capture free-form
 /// company names, debt references, suffixes or amounts; never hide a
 /// posted financial movement merely because its greeting is similar.
 static WaffraSmsLocalRule? _safeGlobalAnnouncementExclusion({
  required String body,
 }){
  final facts=WaffraBankSmsFactsParser.parse(body);
  if(facts.kind!=WaffraBankOperationKind.uncertain||
    _hasPostedMoneyEvidence(body)||_hasCompletedFinanceCue(body)||
    WaffraBankSmsFactsParser.isVerificationChallenge(body))return null;
  final source=normalized(body);
  const patterns=<List<String>>[
   ['نشعركم بصدور','المالك'],
   ['نحيطكم علما بصدور','المالك'],
   ['اشعار بصدور','المنشاه'],
  ];
  for(final keywords in patterns){
   if(!keywords.every((word)=>source.contains(normalized(word))))continue;
   final rule=WaffraSmsLocalRule(
    id:'smart_global_${sha256.convert(utf8.encode(
     'excluded|${keywords.join('|')}')).toString().substring(0,32)}',
    name:'تنبيه خدمي متكرر',kind:'excluded',
    income:false,category:'',sender:'',
    keywords:keywords,matchAll:true,autoPost:false,
   );
   try{validate(rule);if(matches(rule,body))return rule;}
   on FormatException{/* No inferred exclusion on unsafe text. */}
  }
  return null;
 }

 static WaffraSmsLocalRule? suggestedGlobalRule({
  required String body,required String sender,required String kind,
  String category='',bool confidentOnly=true,
 }) {
  final scoped=suggestedRule(body:body,sender:sender,kind:kind,
   category:category,confidentOnly:confidentOnly);
  if(scoped==null)return kind=='excluded'?
   _safeGlobalAnnouncementExclusion(body:body):null;
  final global=WaffraSmsLocalRule(
   id:'${scoped.templateFamily.isEmpty?'smart_global':'template_global'}_${sha256.convert(utf8.encode(
    '$kind|${normalized(scoped.keywords.join('|'))}|${normalized(category)}|${scoped.templateFamily}'
   )).toString().substring(0,32)}',
   name:scoped.name,keywords:scoped.keywords,
   income:scoped.income,category:scoped.category,
   kind:scoped.resolvedKind,sender:'',matchAll:scoped.matchAll,
   autoPost:false,accountId:'',accountSuffix:'',
   templateFamily:scoped.templateFamily,
   contextFragments:scoped.contextFragments,
  );
  try{
   validate(global);
   if(!matches(global,body,sender:sender))return null;
   return global;
  }on FormatException{return null;}
 }

 /// Confirmed manual correction of an UNKNOWN SMS kind may teach a
 /// distinctive merchant phrase globally, without trusting an uncertain bank
 /// direction. A conflicting proven direction, OTP, pending or posted-money
 /// cue never becomes a broader automatic rule from mere text similarity.
 static WaffraSmsLocalRule? suggestedConfirmedGlobalCorrection({
  required String body,required String description,
  required String kind,required String category,
 }){
  if(!const {'income','expense'}.contains(kind)||
    category.trim().isEmpty)return null;
  final facts=WaffraBankSmsFactsParser.parse(body);
  if(facts.pending||facts.kind!=WaffraBankOperationKind.uncertain||
     WaffraBankSmsFactsParser.isVerificationChallenge(body)||
     _hasPostedMoneyEvidence(body))return null;
  final text=waffraMerchantName(body,income:kind=='income')??description;
  final normalizedBody=normalized(body);
  final phrases=safeDescriptionKeywords(text).where((p)=>
   normalized(p).length>=5&&normalizedBody.contains(normalized(p)))
   .take(2).toList(growable:false);
  if(phrases.isEmpty)return null;
  final name=text.trim().length>=2&&text.trim().length<=60?
   text.trim():phrases.first;
  final candidate=WaffraSmsLocalRule(
   id:'smart_global_${sha256.convert(utf8.encode(
    '$kind|${normalized(phrases.join('|'))}|${normalized(category)}'
   )).toString().substring(0,32)}',
   name:name,kind:kind,income:kind=='income',category:category,
   keywords:phrases,sender:'',matchAll:false,autoPost:false,
  );
  try{
   validate(candidate);
   if(!matches(candidate,body,sender:''))return null;
   return candidate;
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
   if(item.length<4||generic.contains(item)||
      _genericBankOperationHeading(item)||!safeKeyword(item))continue;
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
  // Never create category rules from a generic bank heading or its
  // direction words; the owner picked the category for one record only.
  final keywords=safeDescriptionKeywords(description)
   .where((keyword)=>!_genericBankOperationHeading(keyword))
   .toList(growable:false);
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
 /// Correct a saved financial operation without removing other owner's
 /// manually approved rules. Only senderless auto-learned manual buckets
 /// tied to the original category may have their stale phrase removed.
 /// A remaining confirmed operation using the old phrase keeps it alive.
 static List<WaffraSmsLocalRule> reconcileConfirmedManualCorrection({
  required List<WaffraSmsLocalRule> existing,
  WaffraSmsLocalRule? oldCandidate,WaffraSmsLocalRule? newCandidate,
  required bool previousStillUsed,
 }){
  var current=existing;
  if(oldCandidate!=null&&!previousStillUsed){
   final oldPhrases=oldCandidate.keywords.map(normalized).toSet();
   current=<WaffraSmsLocalRule>[
    for(final rule in current)
     if(!rule.id.startsWith('manual_')||rule.autoPost||
        rule.resolvedKind!=oldCandidate.resolvedKind||
        rule.sender!=oldCandidate.sender)rule
     else ...(){
      final retained=rule.keywords.where((phrase)=>
       !oldPhrases.contains(normalized(phrase))||
       (rule.keywordCategories[normalized(phrase)]??rule.category)!=
        oldCandidate.category).toList(growable:false);
      if(retained.length==rule.keywords.length)return <WaffraSmsLocalRule>[rule];
      if(retained.isEmpty)return const <WaffraSmsLocalRule>[];
      final categories=<String,String>{
       for(final phrase in retained)
        normalized(phrase):rule.keywordCategories[normalized(phrase)]??
         rule.category,
      };
      final updated=WaffraSmsLocalRule.fromJson(<String,dynamic>{
       ...rule.toJson(),'keywords':retained,
       'keywordCategories':categories,
      });
      validate(updated);
      return <WaffraSmsLocalRule>[updated];
     }(),
   ];
  }
  if(newCandidate!=null){
   current=upsertLearned(existing:current,candidate:newCandidate);
  }
  return List<WaffraSmsLocalRule>.unmodifiable(current);
 }

 static List<WaffraSmsLocalRule> upsertLearned({
  required List<WaffraSmsLocalRule> existing,
  required WaffraSmsLocalRule candidate,
 }) {
  validate(candidate);
  if(candidate.autoPost||candidate.id.startsWith('custom_')){
   throw const FormatException('Learning cannot grant posting permission');
  }
  // Idempotent across current and overflow buckets. Repeated bank messages
  // must not consume capacity or duplicate a previously approved hint.
  if(existing.any((rule)=>rule.resolvedKind==candidate.resolvedKind&&
   normalized(rule.sender)==normalized(candidate.sender)&&
   candidate.keywords.every((word)=>rule.keywords.any((stored)=>
    normalized(stored)==normalized(word)&&
    (rule.keywordCategories[normalized(stored)]??rule.category)==
     candidate.category))))return existing;
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
  // M1031: a contradictory confirmed direction must NOT silently create
  // two globally matching income/expense rules for the same phrase.
  // Preserve existing owner evidence and leave future SMS in human review.
  if(existing.any((rule)=>rule.financial&&candidate.financial&&
    rule.resolvedKind!=candidate.resolvedKind&&
    normalized(rule.sender)==normalized(candidate.sender)&&
    rule.keywords.any((word)=>candidate.keywords.any(
     (other)=>normalized(word)==normalized(other))))){
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
   rule.accountId==candidate.accountId&&
   <String>{...rule.keywords,...candidate.keywords}.length<=12);
  if(index<0){
   if(existing.length>=maxStoredRules)return existing;
   // A filled 12-phrase learned bucket does not swallow the next verified
   // merchant. Start an independent safe review-only bucket, with a stable
   // collision-free identifier if an old V1 bucket already owns its ID.
   var appended=candidate;
   if(existing.any((r)=>r.id==candidate.id)){
    final identity=sha256.convert(utf8.encode(jsonEncode([
     candidate.id,candidate.resolvedKind,candidate.sender,
     candidate.category,candidate.keywords,
    ]))).toString().substring(0,12);
    final prefix=candidate.id.length>64?
     candidate.id.substring(0,64):candidate.id;
    appended=WaffraSmsLocalRule.fromJson(<String,dynamic>{
     ...candidate.toJson(),'id':'${prefix}_$identity',
    });
    if(existing.any((r)=>r.id==appended.id))return existing;
   }
   validate(appended);
   return List<WaffraSmsLocalRule>.unmodifiable([...existing,appended]);
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
       // Explicit owner-reviewed global templates are permitted: their
       // structural OTP/beneficiary guard still blocks posted money.
       !rule.matchAll||rule.autoPost||
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

/// The number of excluded SMS is NOT the number of generated rules.
/// Only safe, confirmed patterns can become reusable suggestions.
class WaffraSmsRuleLearningResult {
 const WaffraSmsRuleLearningResult({
  required this.proposals,required this.addedOrUpdated,
  required this.activeRules,this.blockedConflicts=0,this.blockedCapacity=0,
 });
 final int proposals,addedOrUpdated,activeRules;
 /// Owners must see why a safe category hint did not become a usable rule.
 final int blockedConflicts,blockedCapacity;
 bool get changed=>addedOrUpdated>0;
}

/// Per-user encrypted app configuration, not a new unverified finance writer.
/// No source SMS or transaction amount is ever persisted here.
class WaffraSmsLocalRuleStore {
 const WaffraSmsLocalRuleStore();
 // Serialize ALL rule writes for the same authenticated owner in this isolate.
 // A bulk-exclusion save cannot overwrite a concurrent manual/confirmation
 // rule update with a stale read-modify-write snapshot.
 static final Map<String,Future<void>> _writeTail={};
 Future<T> _exclusive<T>(String owner,Future<T> Function() action)async{
  _key(owner);
  final before=_writeTail[owner];
  final gate=Completer<void>();
  _writeTail[owner]=gate.future;
  if(before!=null)await before;
  try{return await action();}
  finally{
   if(identical(_writeTail[owner],gate.future))_writeTail.remove(owner);
   gate.complete();
  }
 }
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
  if(rules.length>WaffraSmsLocalRules.maxStoredRules||rules.map((e)=>e.id).toSet().length!=rules.length){
   throw const FormatException('Local rule store failed validation');
  }
  return rules;
 }
 String _historyKey(String owner){
  _key(owner); // Same exact verified-owner validation as live rules.
  return 'waffra_sms_local_rules_history_v1_$owner';
 }
 static List<String> boundedHistory(Iterable<String> snapshots,String previous){
  final next=[...snapshots,previous];
  return List<String>.unmodifiable(
   next.length<=5?next:next.sublist(next.length-5));
 }
 Future<List<String>> _readHistory(String owner)async{
  final raw=await _storage.read(key:_historyKey(owner));
  if(raw==null||raw.isEmpty)return const [];
  final decoded=jsonDecode(raw);
  if(decoded is! List||decoded.length>5||
     decoded.any((e)=>e is! String||e.length>512000)){
   throw const FormatException('Corrupt encrypted SMS rule revision history');
  }
  return decoded.cast<String>();
 }
 Future<bool> hasUndo(String owner)async=>
  (await _readHistory(owner)).isNotEmpty;

 Future<List<WaffraSmsLocalRule>?> undoLast(String owner)=>
  _exclusive(owner,()async{
   final history=await _readHistory(owner);
   if(history.isEmpty)return null;
   final previous=history.last;
   final parsed=jsonDecode(previous);
   if(parsed is! List||parsed.length>WaffraSmsLocalRules.maxStoredRules){
    throw const FormatException('Invalid prior SMS rules');
   }
   final restored=<WaffraSmsLocalRule>[];
   for(final row in parsed){
    if(row is! Map)throw const FormatException('Invalid rule revision row');
    final rule=WaffraSmsLocalRule.fromJson(Map<String,dynamic>.from(row));
    WaffraSmsLocalRules.validate(rule);
    restored.add(rule);
   }
   if(restored.map((r)=>r.id).toSet().length!=restored.length){
    throw const FormatException('Duplicate ID in rule revision');
   }
   await _storage.write(key:_key(owner),value:previous);
   await _storage.write(key:_historyKey(owner),
    value:jsonEncode(history.sublist(0,history.length-1)));
   // Secure storage read-back: a successful API call must really be visible.
   final verified=await read(owner);
   if(jsonEncode(verified.map((r)=>r.toJson()).toList())!=
      jsonEncode(restored.map((r)=>r.toJson()).toList())) {
    throw StateError('SMS rule revision was not persisted.');
   }
   return List<WaffraSmsLocalRule>.unmodifiable(restored);
  });

 Future<void> _writeUnlocked(String owner,List<WaffraSmsLocalRule> rules)async{
  if(rules.length>WaffraSmsLocalRules.maxStoredRules||rules.map((e)=>e.id).toSet().length!=rules.length){
   throw const FormatException('Too many or duplicate rules');
  }
  for(final rule in rules)WaffraSmsLocalRules.validate(rule);
  final key=_key(owner);
  final next=jsonEncode(rules.map((rule)=>rule.toJson()).toList(growable:false));
  final previous=(await _storage.read(key:key))??'[]';
  if(previous==next)return;
  final history=await _readHistory(owner);
  final updated=boundedHistory(history,previous);
  // Only safe patterns, NEVER raw messages or OTP codes, are persisted.
  await _storage.write(key:_historyKey(owner),value:jsonEncode(updated));
  await _storage.write(key:key,value:next);
  final confirmed=await _storage.read(key:key);
  if(confirmed!=next)throw StateError('Encrypted SMS rules were not persisted.');
 }

 Future<void> write(String owner,List<WaffraSmsLocalRule> rules)=>
  _exclusive(owner,()=>_writeUnlocked(owner,rules));

 /// Prevent the settings screen from overwriting rules learned while it was
 /// open. Caller should refresh and ask for the edit again on a stale version.
 Future<void> writeIfCurrent(String owner,{
  required List<WaffraSmsLocalRule> expected,
  required List<WaffraSmsLocalRule> next,
 })=>_exclusive(owner,()async{
  final current=await read(owner);
  String fingerprint(List<WaffraSmsLocalRule> rows)=>
   jsonEncode(rows.map((r)=>r.toJson()).toList(growable:false));
  if(fingerprint(current)!=fingerprint(expected)){
   throw StateError('SMS rules changed in another review. Reload first.');
  }
  await _writeUnlocked(owner,next);
 });

 /// M1032: bank suffix changes instantly revoke previously authorized
 /// posting and account associations. Rule text remains a non-posting hint,
 /// so users can review and explicitly re-approve a new account binding.
 Future<int> disableAccountBoundPosting(String owner,String accountId)=>
  _exclusive(owner,()async{
   if(accountId.trim().isEmpty||accountId.length>128){
    throw ArgumentError('Invalid bank account identity');
   }
   final current=await read(owner);
   final next=<WaffraSmsLocalRule>[
    for(final r in current)
     if(r.accountId==accountId)
      WaffraSmsLocalRule.fromJson(<String,dynamic>{
       ...r.toJson(),
       'autoPost':false,'accountId':'','accountSuffix':'',
      })
     else r,
   ];
   final affected=current.where((r)=>r.accountId==accountId).length;
   if(affected>0)await _writeUnlocked(owner,next);
   return affected;
  });

 /// M1032: the verified ledger edit has already committed. Reconcile
 /// only the old senderless learned phrase, preserving all user/custom
 /// authorizations. A failed learning write NEVER retries the money edit.
 Future<void> reconcileConfirmedCategoryCorrection({
  required String owner,WaffraSmsLocalRule? previous,
  WaffraSmsLocalRule? revised,required bool previousStillUsed,
 })=>_exclusive(owner,()async{
  final current=await read(owner);
  final next=WaffraSmsLocalRules.reconcileConfirmedManualCorrection(
   existing:current,oldCandidate:previous,newCandidate:revised,
   previousStillUsed:previousStillUsed);
  if(revised!=null){
   final relevant=next.any((r)=>r.resolvedKind==revised.resolvedKind&&
    r.sender==revised.sender&&
    r.keywords.any((term)=>revised.keywords.any((word)=>
     WaffraSmsLocalRules.normalized(term)==
      WaffraSmsLocalRules.normalized(word)&&
      (r.keywordCategories[WaffraSmsLocalRules.normalized(term)]??
       r.category)==revised.category)));
   if(!relevant)throw StateError('SMS_RULE_CATEGORY_CONFLICT_OR_CAPACITY');
  }
  if(jsonEncode(current.map((r)=>r.toJson()).toList())!=
     jsonEncode(next.map((r)=>r.toJson()).toList())){
   await _writeUnlocked(owner,next);
  }
 });


 /// M1032: authenticated V3 archives can carry owner-scoped local rules and
 /// encrypted learning observations. Reuse the *same* strict rule validator
 /// used by live classification: no raw SMS, OTP digits or arbitrary bodies.
 /// A destination device must explicitly approve future AutoPost again.
 static Map<String,Object?> validatePortableBackup(Object? payload){
  if(payload is! Map||
     payload.keys.any((key)=>key is! String)||
     payload.keys.toSet().difference(
      const {'version','owner','rules','learning'}).isNotEmpty||
     payload['version']!=1||
     payload['owner'] is! String||
     !RegExp(r'^[a-f0-9]{64}$').hasMatch(payload['owner'] as String)||
     payload['rules'] is! List||
     (payload['rules'] as List).length>WaffraSmsLocalRules.maxStoredRules){
   throw const FormatException('Invalid owner-scoped portable SMS rules');
  }
  final parsed=<WaffraSmsLocalRule>[];
  final seen=<String>{};
  for(final item in payload['rules'] as List){
   if(item is! Map||item.keys.any((key)=>key is! String)){
    throw const FormatException('Invalid SMS rule in portable backup');
   }
   final rule=WaffraSmsLocalRule.fromJson(Map<String,dynamic>.from(item));
   WaffraSmsLocalRules.validate(rule);
   if(!seen.add(rule.id)){
    throw const FormatException('Duplicate SMS rule in portable backup');
   }
   parsed.add(rule);
  }
  final value=payload['learning'];
  Map<String,Object?>? observations;
  if(value!=null){
   if(value is! Map||value.keys.any((key)=>key is! String)||
      value.keys.toSet().difference(
       const {'version','recent','totals','sourceTotals'}).isNotEmpty||
      value['version']!=1||
      value['recent'] is! List||
      (value['recent'] as List).length>512){
    throw const FormatException('Invalid portable confirmed learning');
   }
   final recent=<Map<String,Object?>>[];
   final hashes=<String>{};
   for(final row in value['recent'] as List){
    if(row is! Map||row.keys.toSet().difference(
       const {'id','kind','category','source'}).isNotEmpty||
       row['id'] is! String||
       !RegExp(r'^[a-f0-9]{64}$').hasMatch(row['id'] as String)||
       !hashes.add(row['id'] as String)||
       row['category'] is! String||
       (row['category'] as String).trim().isEmpty||
       (row['category'] as String).length>160||
       !const {'income','expense'}.contains(row['kind'])||
       !const {'manual','sms'}.contains(row['source'])){
     throw const FormatException('Invalid portable confirmed-learning receipt');
    }
    recent.add(<String,Object?>{
     'id':row['id'],'kind':row['kind'],
     'category':row['category'],'source':row['source']});
   }
   Map<String,int> verifyCounts(Object? raw){
    if(raw==null)return <String,int>{};
    if(raw is! Map||raw.length>1024){
     throw const FormatException('Invalid portable learning counters');
    }
    final clean=<String,int>{};
    for(final entry in raw.entries){
     if(entry.key is! String||entry.key.trim().isEmpty||
        entry.key.length>200||entry.value is! int||
        (entry.value as int)<0||(entry.value as int)>0x7fffffffffffffff){
      throw const FormatException('Invalid portable learning count');
     }
     clean[entry.key as String]=entry.value as int;
    }
    return clean;
   }
   observations=<String,Object?>{
    'version':1,'recent':recent,
    'totals':verifyCounts(value['totals']),
    'sourceTotals':verifyCounts(value['sourceTotals']),
   };
  }
  return <String,Object?>{
   'version':1,'owner':payload['owner'],
   'rules':[for(final rule in parsed)rule.toJson()],
   if(observations!=null)'learning':observations,
  };
 }

 /// V3 export operates on the owner-specific Android Keystore storage only.
 /// The enclosing .waffra archive password authenticates the payload.
 Future<Map<String,Object?>> exportPortableBackup(String owner)=>
  _exclusive(owner,()async{
   final rules=await read(owner);
   final raw=await _storage.read(
    key:'waffra_sms_confirmed_finance_learning_v1_$owner');
   return validatePortableBackup(<String,Object?>{
    'version':1,'owner':owner,
    'rules':[for(final rule in rules)rule.toJson()],
    if(raw!=null)'learning':jsonDecode(raw),
   });
  });

 /// Import is separate from the canonical SQLCipher money restore. Do not
 /// report successful local-rule recovery unless secure-store readback works.
 /// Never re-enable automatic posting on a new device/backup recovery.
 Future<void> restorePortableBackup(String owner,Object? payload)=>
  _exclusive(owner,()async{
   final verified=validatePortableBackup(payload);
   if(verified['owner']!=owner){
    throw StateError('Portable rules belong to another authenticated owner');
   }
   final safe=<WaffraSmsLocalRule>[
    for(final item in verified['rules'] as List)
     WaffraSmsLocalRule.fromJson(<String,dynamic>{
      ...Map<String,dynamic>.from(item as Map),
      'autoPost':false,'accountId':'','accountSuffix':'',
     }),
   ];
   for(final rule in safe)WaffraSmsLocalRules.validate(rule);
   final receiptKey='waffra_sms_confirmed_finance_learning_v1_$owner';
   final previousRules=await _storage.read(key:_key(owner));
   final previousReceipt=await _storage.read(key:receiptKey);
   try{
    await _writeUnlocked(owner,safe);
    final restored=await read(owner);
    if(jsonEncode(restored.map((r)=>r.toJson()).toList())!=
       jsonEncode(safe.map((r)=>r.toJson()).toList())){
     throw StateError('Portable SMS rule readback differs');
    }
    if(verified['learning']!=null){
     final next=jsonEncode(verified['learning']);
     await _storage.write(key:receiptKey,value:next);
     if(await _storage.read(key:receiptKey)!=next){
      throw StateError('Portable learning readback differs');
     }
    }else{
     await _storage.delete(key:receiptKey);
     if(await _storage.read(key:receiptKey)!=null){
      throw StateError('Portable learning delete failed');
     }
    }
   }catch(_){
    // Preserve pre-existing local classification if this non-transactional
    // OS Keystore operation fails. Money restoration is never replayed.
    try{
     if(previousRules==null){await _storage.delete(key:_key(owner));}
     else{await _storage.write(key:_key(owner),value:previousRules);}
     if(previousReceipt==null){await _storage.delete(key:receiptKey);}
     else{await _storage.write(key:receiptKey,value:previousReceipt);}
    }catch(_){/* Caller still reports incomplete local recovery. */}
    rethrow;
   }
  });

 /// Atomically combine safe financial/exclusion suggestions with latest
 /// encrypted owner rules instead of racing the four entry points.
 /// M1031: every confirmed manual/SMS Income/Expense leaves an encrypted,
 /// owner-scoped, idempotent learning receipt EVEN when its generic title
 /// has no safe SMS-matching keyword. This is not a finance or AutoPost rule.
 /// Only safe, separately validated patterns are put into active rule lists.
 Future<bool> recordConfirmedFinanceLearning({
  required String owner,required String transactionId,
  required String sourceType,required bool income,required String category,
 })=>_exclusive(owner,()async{
  if(transactionId.trim().isEmpty||transactionId.length>180||
     !const {'manual','sms'}.contains(sourceType)||
     category.trim().isEmpty||category.length>160){
   throw const FormatException('Confirmed learning source invalid');
  }
  final digest=sha256.convert(utf8.encode(
   '$owner|$sourceType|$transactionId')).toString();
  final key='waffra_sms_confirmed_finance_learning_v1_$owner';
  final old=await _storage.read(key:key);
  final parsed=old==null?<String,Object?>{}:jsonDecode(old);
  if(parsed is! Map)throw const FormatException(
   'Confirmed learning history unreadable');
  final doc=Map<String,Object?>.from(parsed);
  final recent=(doc['recent'] as List? ??const [])
   .whereType<Map>().map((row)=>Map<String,Object?>.from(row))
   .toList(growable:true);
  if(recent.length>512||recent.any((row)=>
    row['id'] is! String||row['kind'] is! String)) {
   throw const FormatException('Invalid confirmed learning history');
  }
  if(recent.any((row)=>row['id']==digest))return true;
  final kind=income?'income':'expense';
  final totals=<String,int>{};
  final sourceTotals=doc['totals'];
  if(sourceTotals is Map){
   for(final pair in sourceTotals.entries){
    if(pair.key is! String||pair.value is! int||
       (pair.value as int)<0)throw const FormatException(
        'Invalid confirmed learning totals');
    totals[pair.key as String]=pair.value as int;
   }
  }
  final bySource=<String,int>{};
  if(doc['sourceTotals'] is Map){
   for(final entry in (doc['sourceTotals'] as Map).entries){
    if(entry.key is! String||entry.value is! int||
       (entry.value as int)<0)throw const FormatException(
        'Invalid source learning totals');
    bySource[entry.key as String]=entry.value as int;
   }
  }else{
   // Backward compatibility for the first M1031 verified receipts created
   // before the by-source counter existed.
   for(final row in recent){
    final src=row['source'],type=row['kind'];
    if(src is String&&type is String){
     final key='$src|$type';
     bySource[key]=(bySource[key]??0)+1;
    }
   }
  }
  final bucket='$kind|$category';
  totals[bucket]=(totals[bucket]??0)+1;
  final sourceKey='$sourceType|$kind';
  bySource[sourceKey]=(bySource[sourceKey]??0)+1;
  recent.add(<String,Object?>{
   'id':digest,'kind':kind,'category':category.trim(),
   'source':sourceType,
  });
  if(recent.length>512)recent.removeRange(0,recent.length-512);
  final next=jsonEncode(<String,Object?>{
   'version':1,'recent':recent,'totals':totals,
   'sourceTotals':bySource,
  });
  await _storage.write(key:key,value:next);
  final reloaded=await _storage.read(key:key);
  if(reloaded!=next)throw StateError(
   'Confirmed local learning did not survive encrypted readback');
  return true;
 });

 /// Read-only statistics: a confirmed learning observation is NOT
 /// necessarily a safely reusable SMS keyword pattern. Never display
 /// missing/decryption-failed statistics as a misleading zero.
 Future<Map<String,int>> confirmedFinanceLearningCounts(String owner)async{
  _key(owner);
  final raw=await _storage.read(
   key:'waffra_sms_confirmed_finance_learning_v1_$owner');
  if(raw==null)return const <String,int>{
   'manual|income':0,'manual|expense':0,
   'sms|income':0,'sms|expense':0,
  };
  final doc=jsonDecode(raw);
  if(doc is! Map)throw const FormatException(
   'Confirmed local learning ledger unreadable');
  final counts=<String,int>{
   'manual|income':0,'manual|expense':0,
   'sms|income':0,'sms|expense':0,
  };
  final encoded=doc['sourceTotals'];
  if(encoded is Map){
   for(final entry in encoded.entries){
    if(entry.key is! String||entry.value is! int||
       (entry.value as int)<0)throw const FormatException(
        'Invalid confirmed local learning counter');
    if(counts.containsKey(entry.key))counts[entry.key as String]=entry.value as int;
   }
  }else{
   // Read legacy M1031 bounded history without erasing or changing it.
   final rows=doc['recent'];
   if(rows is! List)throw const FormatException(
    'Confirmed learning snapshot missing');
   for(final row in rows){
    if(row is! Map)throw const FormatException('Invalid learning record');
    final source=row['source'],kind=row['kind'];
    final bucket='$source|$kind';
    if(counts.containsKey(bucket))counts[bucket]=counts[bucket]!+1;
   }
  }
  return Map<String,int>.unmodifiable(counts);
 }

 Future<WaffraSmsRuleLearningResult> learnReviewedCandidates(
  String owner,Iterable<WaffraSmsLocalRule> candidates,
 )=>_exclusive(owner,()async{
  final current=await read(owner);
  var next=current;
  var offered=0;
  var conflict=0,capacity=0;
  for(final candidate in candidates){
   offered++;
   final before=next;
   next=WaffraSmsLocalRules.upsertLearned(existing:next,candidate:candidate);
   if(identical(before,next)&&candidate.financial){
    final overlap=before.any((existing)=>
     existing.sender==candidate.sender&&
     existing.keywords.any((phrase)=>candidate.keywords.any((other)=>
      WaffraSmsLocalRules.normalized(phrase)==
       WaffraSmsLocalRules.normalized(other)))&&
     (existing.resolvedKind!=candidate.resolvedKind||
      existing.category!=candidate.category));
    if(overlap)conflict++;
    else if(before.length>=WaffraSmsLocalRules.maxStoredRules||
     before.any((r)=>!r.autoPost&&!r.matchAll&&
      r.resolvedKind==candidate.resolvedKind&&
      r.sender==candidate.sender&&
      r.keywords.toSet().union(candidate.keywords.toSet()).length>12)){
     capacity++;
    }
   }
  }
  final changed=next.length!=current.length||
   jsonEncode(next.map((r)=>r.toJson()).toList())!=
    jsonEncode(current.map((r)=>r.toJson()).toList());
  if(changed)await _writeUnlocked(owner,next);
  final verified=await read(owner);
  if(jsonEncode(verified.map((r)=>r.toJson()).toList())!=
     jsonEncode(next.map((r)=>r.toJson()).toList())){
   throw StateError('Saved SMS rules differ from the requested patterns.');
  }
  return WaffraSmsRuleLearningResult(
   proposals:offered,addedOrUpdated:changed?
    next.where((r)=>!current.any((c)=>c.id==r.id&&
     jsonEncode(c.toJson())==jsonEncode(r.toJson()))).length:0,
   activeRules:verified.length,
   blockedConflicts:conflict,blockedCapacity:capacity);
  });

}
