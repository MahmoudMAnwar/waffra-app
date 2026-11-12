import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_approved_notifications.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

void main() {
 testWidgets('M665 notification pull triggers one incremental rescan, no AppBar refresh', (tester)async{
  var rescans=0;
  await tester.pumpWidget(MaterialApp(home:WaffraApprovedNotificationsPage(
   english:false,
   readPending:()=>[const WaffraReviewNotice(
    id:'pull_sms',sender:'SyntheticBank',preview:'Review only')],
   onReviewAll:()async{},onReviewOne:(id)async{},
   onRescan:()async{rescans++;},canRescan:()=>true,
  )));
  expect(find.byKey(const Key('m665-notification-pull-refresh')),findsOneWidget);
  expect(find.byIcon(Icons.refresh_rounded),findsNothing);
  await tester.drag(find.byKey(const Key('m549-notification-list')),
   const Offset(0,420));
  await tester.pump();
  await tester.pump(const Duration(seconds:1));
  expect(rescans,1);
 });

 group('M665 / M660 safe, sender-scoped SMS template learning', () {
  test('one approved OTP covers other verification wording, not financial debit', () {
   const first='رمز التفعيل الخاص بك هو 482913، لا تشارك الرمز';
   const next='رمز التحقق الخاص بك هو 889100، لا تشارك الرمز';
   final rule=WaffraSmsLocalRules.suggestedRule(
    body:first,sender:'AlRajhiBank',kind:'excluded',confidentOnly:true);
   expect(rule,isNotNull);
   expect(rule!.templateFamily,'verification');
   expect(rule.matchAll,isTrue);
   expect(rule.autoPost,isFalse);
   expect(rule.toJson().toString(),isNot(contains('482913')));
   expect(WaffraSmsLocalRules.matches(rule,next,sender:'AlRajhiBank'),isTrue);
   expect(WaffraSmsLocalRules.matches(rule,next,sender:'UnrelatedBank'),isFalse);
   expect(WaffraSmsLocalRules.matches(rule,
    'تم خصم 300 ريال. رمز التحقق 889100',
    sender:'AlRajhiBank'),isFalse);
   final restored=WaffraSmsLocalRule.fromJson(
    Map<String,dynamic>.from(rule.toJson()));
   WaffraSmsLocalRules.validate(restored);
   expect(restored.templateFamily,rule.templateFamily);
  });

  test('approved beneficiary management survives name and verb replacement', () {
   const source='تمت إضافة المستفيد: محمد صابر خليل محمد';
   final rule=WaffraSmsLocalRules.suggestedRule(
    body:source,sender:'AlRajhiBank',kind:'excluded',confidentOnly:true);
   expect(rule,isNotNull);
   expect(rule!.templateFamily,'beneficiary_management');
   expect(rule.toJson().toString(),isNot(contains('محمد صابر')));
   const next='تم تنشيط المستفيد: أحمد علي';
   expect(WaffraSmsLocalRules.matches(rule,next,sender:'AlRajhiBank'),isTrue);
   expect(WaffraSmsLocalRules.matches(rule,next,sender:'OtherBank'),isFalse);
   expect(WaffraSmsLocalRules.matches(rule,
    'تم خصم 50 ريال، تمت إضافة المستفيد: أحمد علي',
    sender:'AlRajhiBank'),isFalse);
   expect(WaffraSmsLocalRules.matches(rule,
    'تم تحويل 100 ريال إلى المستفيد أحمد',
    sender:'AlRajhiBank'),isFalse);
   expect(WaffraSmsLocalRules.matches(rule,
    'تم تحويل 100 ريال. تم تنشيط المستفيد: أحمد',
    sender:'AlRajhiBank'),isFalse,
    reason:'A completed transfer event must defeat an exclusion template');
   final facts=WaffraBankSmsFactsParser.parse(next);
   expect(facts.kind,WaffraBankOperationKind.uncertain);
   final resolved=WaffraSmsLocalRules.resolveSpecial(
    body:next,sender:'AlRajhiBank',bankKind:facts.kind,custom:[rule]);
   expect(resolved?.id,rule.id);
  });

  test('one approved template is stable and never enables finance auto-post', () {
   final rule=WaffraSmsLocalRules.suggestedRule(
    body:'تمت إضافة المستفيد: محمد',sender:'AlRajhiBank',
    kind:'excluded',confidentOnly:true)!;
   final saved=WaffraSmsLocalRules.upsertLearned(
    existing:const <WaffraSmsLocalRule>[],candidate:rule);
   final again=WaffraSmsLocalRules.upsertLearned(
    existing:saved,candidate:rule);
   expect(saved,hasLength(1));
   expect(again,hasLength(1));
   expect(again.single.autoPost,isFalse);
   expect(again.single.sender,'AlRajhiBank');
   expect(again.single.contextFragments,everyElement(isNot(contains('محمد'))));
  });

  test('reviewed income and transfer hints stay separate from posting authority', () {
   final income=WaffraSmsLocalRules.suggestedRule(
    body:'Refund Received\nAmount: SAR 50.00',
    sender:'AlRajhiBank',kind:'income',
    category:'مبالغ مستردة / استرجاع مشتريات',confidentOnly:true);
   final transfer=WaffraSmsLocalRules.suggestedRule(
    body:'Credit Transfer via Alinma Bank\nAmount: SAR 1900.00',
    sender:'AlinmaBank',kind:'transfer');
   expect(income,isNotNull);
   expect(transfer,isNotNull);
   expect(income!.autoPost,isFalse);
   expect(transfer!.autoPost,isFalse);
   expect(income.matchAll,isTrue);
   expect(transfer.matchAll,isTrue);
   expect(transfer.financial,isFalse);
  });
 });

 test('M665.6 all 14 ready excluded templates match but never post money',(){
  final seeds=WaffraSmsLocalRules.allDefaultRules.where(
   (r)=>r.builtIn&&r.id.startsWith('sa_excluded_')).toList();
  expect(seeds,hasLength(14));
  for(final rule in seeds){
   final message=rule.keywords.first;
   final result=WaffraSmsLocalRules.resolveSpecial(
    body:message,sender:'TestBank',
    bankKind:WaffraBankOperationKind.uncertain);
   expect(result?.resolvedKind,'excluded',reason:'${rule.id}: $message');
   expect(result?.autoPost,isFalse);
  }
  // Generic finance verbs in non-posted coupons/reminders cannot override
  // a curated exclusion; only independently posted-money evidence can.
  for(final benign in const <String>[
   'خصم حصري', 'payment reminder',
  ]){
   final result=WaffraSmsLocalRules.resolveSpecial(
    body:benign,sender:'TestBank',
    bankKind:WaffraBankOperationKind.expense);
   expect(result?.resolvedKind,'excluded',reason:benign);
  }
  for(final benign in const <String>[
   'خصم حصري اليوم', 'payment reminder', 'عرض خاص اليوم',
   'كود خصم', 'Your verification code is 123456',
   'New login detected on your account',
  ]){
   final matched=WaffraSmsLocalRules.resolveSpecial(
    body:benign,sender:'TestBank',
    bankKind:WaffraBankOperationKind.uncertain);
   expect(matched?.resolvedKind,'excluded',reason:benign);
  }
 });

 test('M665.6 completed bank movements override generic ready exclusions',(){
  for(final posted in const <String>[
   'Card Purchase SAR 75.00 OTP verification code 123456',
   'تم خصم 300 ريال. رمز التحقق 889100',
   'تم تحويل 100 ريال إلى المستفيد أحمد. رمز التحقق 999999',
   'حوالة صادرة بقيمة 1900 ريال. عرض خاص',
   'Payment completed SAR 250. promo code',
   'Salary deposit SAR 5000. OTP code 882233',
   'Credit Transfer via Alinma Bank Amount SAR 1900. OTP 123456',
   'حوالة محلية صادرة بقيمة 1900 ريال. رمز التحقق 123456',
   'تم دفع 200 ريال. كود خصم اليوم',
   'Credit Card Payment SAR 190. OTP 829910',
  ]){
   final matched=WaffraSmsLocalRules.resolveSpecial(
    body:posted,sender:'TestBank',
    bankKind:WaffraBankOperationKind.uncertain);
   expect(matched?.resolvedKind,isNot('excluded'),reason:posted);
  }
 });

 group('M665 visual and event lifecycle source guards', () {
  test('compact review retains main and child correction on current sheet', () {
   final main=File('lib/main.dart').readAsStringSync();
   final start=main.indexOf(' Future<void> _reviewAutoSmsCandidates(');
   final end=main.indexOf(' void _receiveSharedSms(',start);
   final review=main.substring(start,end);
   expect(review,contains("Key('m665-review-pick-category')"));
   expect(review,isNot(contains('PopupMenuButton<String>(')));
   expect(review,isNot(contains('Optional AI review')));
   expect(review,isNot(contains('تحليل اختياري بالذكاء الاصطناعي')));
   expect(review,isNot(contains('ليست عملية مالية')));
   expect(review,isNot(contains("decision=='ai'")));
   expect(review,contains("Key('m595-review-single-exclude')"));
   expect(review,contains("Key('m587-sms-transfer-exclude')"));
   expect(main,isNot(contains('Future<void> _analyzeAmbiguousSmsOnDemand(')));

   expect(review,contains('reviewedCategory=chosen.name;'));
   expect(review,contains('reviewedAccount=(ids:<String?>[pickedId],'));
   expect(review,contains('generation:fresh.witness.generation);'));
   expect(review,contains('reviewCategoryValid'));
   expect(review,contains('category:reviewedCategory,income:expectedIncome,'));
   expect(review,contains(
    'if(!sensitive&&!understood&&\n          facts.kind!=WaffraBankOperationKind.transfer)Padding('));
   expect(review,isNot(contains('راجع البيانات الناقصة من شاشة التعديل')));
   expect(main,contains("Key('waffra-entry-original-sms-expand')"));
  });

  test('notification rescan moved to pull; bulk select stays sender-sticky', () {
   final ui=File('lib/waffra_approved_notifications.dart').readAsStringSync();
   expect(ui,contains("Key('m665-notification-pull-refresh')"));
   expect(ui,contains('RefreshIndicator('));
   expect(ui,contains('AlwaysScrollableScrollPhysics()'));
   expect(ui,isNot(contains('Icons.refresh_rounded')));
   expect(ui,contains('Icons.check_box_outline_blank_rounded'));
   expect(ui,contains('Icons.check_box_rounded'));
   expect(ui,contains('filter=key;'));
   expect(ui,contains('selectedIds.add(item.id)'));
  });

  test('after secure rule write, classify queue without rescanning phone history', () {
   final main=File('lib/main.dart').readAsStringSync();
   final start=main.indexOf(' Future<bool> _learnSafeSmsRule({');
   final end=main.indexOf(' Future<void> _learnManualTransferPreference()',start);
   final fragment=main.substring(start,end);
   expect(fragment,contains('await store.write(_smsRuleOwnerKey,updated);'));
   expect(fragment,contains('_receiveAutoSmsNotice();'));
   expect(fragment,isNot(contains('importConsentMonthChecked()')));
   expect(main,contains('await compute(waffraM632ClassifySmsQueue'));
   expect(main,contains("if(local['kind']=='excluded'){"));
  });
 });

 test('M665.5 built-in ready-rule UI keeps four expandable groups but no essay',(){
  final page=File('lib/waffra_sms_rule_settings_page.dart').readAsStringSync();
  expect(page,contains("'Ready-made rules':'القواعد الجاهزة'"));
  expect(page,isNot(contains("'Built-in Saudi rules':'القواعد السعودية الجاهزة'")));
  expect(page,isNot(contains('قواعد عربية وإنجليزية محلية شغالة من أول تثبيت')));
  expect(page,isNot(contains('Offline Arabic/English suggestions active on every installation')));
  final start=page.indexOf("Text(widget.english?'Ready-made rules':'القواعد الجاهزة'");
  expect(start,greaterThanOrEqualTo(0));
  final group=page.substring(start);
  expect(group,contains("for(final kind in const <String>['income','expense','transfer','excluded'])"));
  expect(group,contains('_defaultRuleBucket(kind)'));
  expect(page,contains("Key('waffra-sms-default-rule-bucket-\$kind')"));
  expect(page,contains('values.length'));
  expect(page,contains('rule.keywords.join'));
 });

 test('M665.5 initial scan applies four ready-rule kinds without auto finance posting',(){
  for(final kind in const ['income','expense','transfer','excluded']){
   expect(WaffraSmsLocalRules.allDefaultRules
    .where((rule)=>rule.resolvedKind==kind),isNotEmpty,
    reason:'Ready-made \$kind bucket is active on first install');
  }
  final main=File('lib/main.dart').readAsStringSync();
  final begin=main.indexOf('Map<String,Object?> waffraM632ClassifySmsQueue(');
  final end=main.indexOf('List<String> splitBankMessages(',begin);
  expect(begin,greaterThanOrEqualTo(0));
  expect(end,greaterThan(begin));
  final worker=main.substring(begin,end);
  expect(worker,contains('WaffraSmsLocalRules.resolveSpecial('));
  expect(worker,contains('WaffraSmsLocalRules.resolve('));
  expect(worker,contains("if(local['kind']=='excluded'){"));
  expect(worker,contains('waiting.add(annotated);'));
  expect(worker,isNot(contains('commitConfirmedSms(')));
  expect(worker,isNot(contains('commitConfirmedManual(')));
  final refresh=main.substring(
   main.indexOf(' Future<void> _runAutoSmsRefresh({'),
   main.indexOf(' Future<void> _scanPreviousBankSmsFromSettings()async{'));
  expect(refresh,contains('WaffraSmsLocalRuleStore().read('));
  expect(refresh,contains('await compute(waffraM632ClassifySmsQueue'));
  expect(refresh,contains("WaffraAutoSms.excludeMessages(batch)"));
 });
}
