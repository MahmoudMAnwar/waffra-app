import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart' show
 defaultCategories,waffraM632ClassifySmsQueue,bankSmsHash;
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

/// M954 uses synthetic content only. This tests the same isolate rules that
/// operate on native pending candidates; no OTP, bank account or phone source
/// is used. A queue exclusion is not a financial posting.
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 const savedExclude=WaffraSmsLocalRule(
  id:'m954_my_app_exclude',name:'App onboarding notices',
  kind:'excluded',income:false,category:'',
  sender:'MyApp',keywords:['تفعيل الحساب'],
  matchAll:false);
 const expenseWrongDirection=WaffraSmsLocalRule(
  id:'m954_wrong_income',name:'Incorrect income suggestion',
  kind:'income',income:true,category:'راتب / راتب أساسي',
  sender:'AlRajhiBank',keywords:['العثيم'],matchAll:false);

 Map<String,Object?> sms(String id,String sender,String body,
  {bool nativeSensitive=false})=><String,Object?>{
   'id':id.padRight(64,'a'),'sender':sender,'body':body,
   'receivedAt':DateTime.utc(2026,11,15).millisecondsSinceEpoch,
   'sensitiveOtp':nativeSensitive,
  };

 Map<String,Object?> scan(List<Map<String,Object?>> rows,{
  List<WaffraSmsLocalRule> custom=const [],
  List<String> hashes=const [],
 })=>waffraM632ClassifySmsQueue(<String,Object?>{
  'results':rows,
  'rules':custom.map((r)=>r.toJson()).toList(growable:false),
  'categories':defaultCategories().where((c)=>c.isSubcategory)
   .map((c)=>'${c.income?'1':'0'}:${c.name}').toList(growable:false),
  'hashes':hashes,
 });

 List<String> ids(Map<String,Object?> result,String field)=>
  (result[field] as List).map((e)=>e.toString()).toList();

 test('M954 Arabic newly installed app code is excluded before UI, 30-day native ACK',(){
  const body='رمزك هو 483926 لتفعيل تطبيق جديد';
  expect(WaffraBankSmsFactsParser.isVerificationChallenge(body),isTrue);
  final m=sms('1','NewApp',body,nativeSensitive:true);
  final result=scan([m]);
  expect(ids(result,'excluded'),[m['id']]);
  expect(result['waiting'],isEmpty);
  expect(result['committed'],isEmpty);
 });

 test('M954 unfamiliar English login code is excluded even when digits masked',(){
  const body='Your login code is •••••• for NewApp';
  final m=sms('2','NewApp',body,nativeSensitive:true);
  final result=scan([m]);
  expect(ids(result,'excluded'),[m['id']]);
  expect(result['waiting'],isEmpty);
 });

 test('M954 Arabic and English app security phrases share one default resolver',(){
  for(final body in <String>[
   'رمز التوثيق 123456 خاص بخدمة جديدة',
   'كود المصادقة: 112233',
   'رمز تسجيل الدخول 123456',
   'Login code 123456 for TestApp',
   'Authentication code: 123456',
   'Your code is 123456 for NewApp',
  ]){
   expect(WaffraBankSmsFactsParser.isVerificationChallenge(body),isTrue,
    reason:body);
   final matched=WaffraSmsLocalRules.resolveSpecial(body:body,sender:'NewApp',
    bankKind:WaffraBankOperationKind.uncertain);
   expect(matched?.resolvedKind,'excluded',reason:body);
  }
 });

 test('M954 exact matching saved sender exclusion runs BEFORE financial templates',(){
  const body='تفعيل الحساب لتطبيق تجريبي';
  final row=sms('3','MyApp',body);
  final matched=scan([row],custom:[savedExclude]);
  expect(ids(matched,'excluded'),[row['id']]);
  expect(matched['waiting'],isEmpty);
  final other=sms('4','DifferentApp',body);
  final unrelated=scan([other],custom:[savedExclude]);
  expect(unrelated['excluded'],isEmpty);
  expect((unrelated['waiting'] as List),hasLength(1));
 });

 test('M954 built-in promo exclusion applies without custom rules',(){
  final row=sms('5','PromoApp','خصم حصري على عضويتك الجديدة');
  final result=scan([row]);
  expect(ids(result,'excluded'),[row['id']]);
  expect(result['waiting'],isEmpty);
 });

 test('M954 existing user rule plus default OTP apply together, no precedence loss',(){
  final myApp=sms('6','MyApp','تفعيل الحساب لتطبيق تجريبي');
  final newApp=sms('7','NewApp','رمز التحقق: ••••••',nativeSensitive:true);
  final result=scan([myApp,newApp],custom:[savedExclude]);
  expect(ids(result,'excluded'),[myApp['id'],newApp['id']]);
  expect(result['waiting'],isEmpty);
 });

 test('M954 OTP plus completed debit is NEVER silently excluded',(){
  final row=sms('8','AlRajhiBank',
   'تم خصم 85 ريال من حسابك. رمز التحقق ••••••',
   nativeSensitive:true);
  final result=scan([row]);
  expect(result['excluded'],isEmpty);
  expect((result['waiting'] as List),hasLength(1));
  expect(result['committed'],isEmpty);
 });

 test('M954 OTP plus completed bank transfer stays in review',(){
  final row=sms('9','AlRajhiBank',
   'حوالة صادرة بمبلغ 140 ريال. رمز التحقق ••••••',
   nativeSensitive:true);
  final result=scan([row]);
  expect(result['excluded'],isEmpty);
  expect((result['waiting'] as List),hasLength(1));
 });

 test('M954 real income and expense remain visible, with finance-only categories',(){
  final income=sms('a','Bank','تم إيداع راتب 7000 ريال في حسابك');
  final expense=sms('b','AlRajhiBank',
   'شراء عبر نقاط البيع مبلغ 236 ريال التاجر العثيم');
  final result=scan([income,expense]);
  expect(result['excluded'],isEmpty);
  expect((result['waiting'] as List),hasLength(2));
  expect(result['committed'],isEmpty);
  for(final item in (result['waiting'] as List)){
   final row=Map<String,Object?>.from(item as Map);
   expect(row['id'],isNotNull);
   expect(row['body'],isNotNull);
  }
 });

 test('M954 user financial rule cannot override source-confirmed expense direction',(){
  final row=sms('c','AlRajhiBank',
   'شراء عبر نقاط البيع مبلغ 236 ريال التاجر العثيم');
  final output=scan([row],custom:[expenseWrongDirection]);
  expect(output['excluded'],isEmpty);
  final waiting=(output['waiting'] as List);
  expect(waiting,hasLength(1));
  final local=(waiting.single as Map)['local'] as Map?;
  expect(local?['income'],isNot(true));
 });

 test('M954 pending nonfinancial unknown goes for review, never saves money',(){
  final row=sms('d','UnknownApp','أهلًا بك في خدمة جديدة');
  final result=scan([row]);
  expect(result['excluded'],isEmpty);
  expect((result['waiting'] as List),hasLength(1));
  expect(result['committed'],isEmpty);
 });

 test('M954 legacy body-only finance hash needs owner review, never silent duplicate ACK',(){
  const body='رمز التحقق ••••••';
  final row=sms('e','ServiceApp',body,nativeSensitive:true);
  final result=scan([row],hashes:[bankSmsHash(body)]);
  expect(result['committed'],isEmpty);
  expect(result['excluded'],isEmpty);
  final waiting=(result['waiting'] as List).cast<Map<String,Object?>>();
  expect(waiting.map((value)=>value['id']).toList(),[row['id']]);
  expect(waiting.single['possibleLegacyDuplicate'],isTrue);
 });

 test('M954 excluded candidate remains recoverable on native ACK failure',(){
  final row=sms('f','PromoApp','عرض حصري لك اليوم');
  final result=scan([row]);
  expect(ids(result,'excluded'),[row['id']]);
  final retain=result['retainOnAckFailure'] as List;
  expect(retain,hasLength(1));
  expect((retain.single as Map)['id'],row['id']);
 });

 test('M954 background and foreground share resolver and durable native markers',(){
  final ui=File('lib/main.dart').readAsStringSync();
  final home=File('lib/waffra_home_sms_refresh.part.dart').readAsStringSync();
  final background=File('lib/waffra_auto_sms_autopost.part.dart').readAsStringSync();
  final android=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  expect(ui,contains('nativeSensitiveOtp:annotated['+"'sensitiveOtp'"+']==true'));
  expect(background,contains('nativeSensitiveOtp:row['+"'sensitiveOtp'"+']==true'));
  expect(background,contains('WaffraSmsLocalRules.resolveSpecial('));
  expect(background,contains('WaffraAutoSms.excludeMessages([id])'));
  expect(background,isNot(contains('WaffraAutoSms.acknowledge([id])')));
  expect(home,contains('WaffraAutoSms.excludeMessages(batch)'));
  expect(android,contains('excludedLabelRetentionMs = 30L * 24 * 60 * 60 * 1000'));
  expect(android,contains('isExcludedMessageLocked(context, fingerprint)'));
  expect(background.indexOf('WaffraAutoSms.excludeMessages([id])'),
   lessThan(background.indexOf('keepForReview(candidate);')));
 });

 test('M954 explicit owner exclusion is checked even if bank heuristic is expense',(){
  // A weak parser decision is not posted-money evidence or a veto on
  // a confirmed sender-scoped rule.
  const body='تفعيل الحساب لتطبيق تجريبي';
  final matched=WaffraSmsLocalRules.resolveSpecial(
   body:body,sender:'MyApp',bankKind:WaffraBankOperationKind.expense,
   custom:[savedExclude]);
  expect(matched?.resolvedKind,'excluded');
  expect(matched?.id,savedExclude.id);
 });

 test('M954 curated reminder is excluded but a completed payment plus OTP is kept',(){
  const reminder='Payment reminder: your bill is due tomorrow';
  final rule=WaffraSmsLocalRules.resolveSpecial(body:reminder,
   sender:'Bank',bankKind:WaffraBankOperationKind.uncertain);
  expect(rule?.resolvedKind,'excluded');
  const posted='Payment completed SAR 75.00. Your verification code is 123456';
  final unsafe=WaffraSmsLocalRules.resolveSpecial(body:posted,
   sender:'Bank',bankKind:WaffraBankOperationKind.uncertain,
   nativeSensitiveOtp:true);
  expect(unsafe?.resolvedKind,isNot('excluded'));
 });

 test('M954 no raw security code persisted by native SMS intake',(){
  final source=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  expect(source,contains('val masked = if (sensitive) redactMixedOtpSecrets(body) else body.trim()'));
  expect(source,contains('.put("body", masked)'));
  expect(source,contains('.put("sensitiveOtp", sensitive)'));
  expect(source,contains('if (isCommittedLocked(context, fingerprint) ||'));
 });
}
