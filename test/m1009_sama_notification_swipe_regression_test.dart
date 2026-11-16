import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_approved_notifications.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_local_rules.dart';
import 'package:waffra/main.dart' show bankSmsDate, bankSmsHasUnverifiedTimestamp, waffraM632ClassifySmsQueue;

const outgoing='حوالة داخلية صادرة\nمن: محمود شحاته\nمبلغ:SAR 60.00\n'
 'إلى: أنور عبد الله\nحساب:**8647\nالرسوم:0\n'
 'الرقم المرجعي:FT26319QPRW3\nفي:15-11-2026 10:14';

void main(){
 test('M1009 SAMA outgoing is an expense candidate, not own account transfer',(){
  final facts=WaffraBankSmsFactsParser.parse(outgoing);
  expect(facts.kind,WaffraBankOperationKind.expense);
  expect(facts.pending,isFalse);
  expect(bankSmsDate(outgoing),DateTime(2026,11,15,10,14));
  expect(bankSmsHasUnverifiedTimestamp(outgoing),isFalse);
  for(final text in [
   'حوالة صادرة داخلية\nمبلغ SAR 120.00\nفي:15-11-2026 11:35',
   'حوالة محلية صادرة\nمبلغ SAR 20.00',
   'Debit Transfer Internal\nAmount: SAR 60.00',
   'Outgoing transfer\nAmount: SAR 40.00',
  ]){
   expect(WaffraBankSmsFactsParser.parse(text).kind,
    WaffraBankOperationKind.expense,reason:text);
  }
  for(final text in [
   'حوالة واردة داخلية\nمبلغ SAR 40.00',
   'حوالة محلية واردة\nمبلغ SAR 75.00',
   'Credit Transfer Internal\nAmount: SAR 50.00',
  ]){
   expect(WaffraBankSmsFactsParser.parse(text).kind,
    WaffraBankOperationKind.income,reason:text);
  }
  expect(WaffraBankSmsFactsParser.parse(
   'حوالة صادرة بين حساباتك\nمبلغ SAR 60.00').kind,
    WaffraBankOperationKind.transfer);
  expect(WaffraBankSmsFactsParser.parse(
   'حوالة واردة بين حساباتك\nمبلغ SAR 60.00').kind,
    WaffraBankOperationKind.transfer);
 });

 test('M1009 confirmed expense teaches same safe heading across new amount/sender',(){
  // Unlike a financial write, learning only authorizes a screen suggestion.
  final learned=WaffraSmsLocalRules.suggestedGlobalRule(
   body:outgoing,sender:'AlinmaPay',kind:'expense',
   category:'حوالات صادرة / حوالة محلية');
  expect(learned,isNotNull);
  expect(learned!.sender,isEmpty);
  expect(learned.autoPost,isFalse);
  expect(learned.keywords.any((s)=>s.contains('حوالة داخلية صادرة')),isTrue);
  const second='حوالة داخلية صادرة\nمن: صاحب الحساب\nمبلغ:SAR 175.00\n'
   'إلى: مستفيد آخر\nحساب:**8765\nالرسوم:0\n'
   'الرقم المرجعي:FT999999ABC\nفي:15-11-2026 10:15';
  final matched=WaffraSmsLocalRules.matchAllFourKinds(
   body:second,sender:'AnotherBank',custom:[learned]);
  expect(matched.any((r)=>r.id==learned.id),isTrue);
  final worker=waffraM632ClassifySmsQueue({
   'results':[{
     'id':'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','sender':'AnotherBank','body':second,
     'receivedAt':1763200000000,
   }],
   'rules':[learned.toJson()],
   'categories':['0:${learned.category}'],
   'hashes':<String>[],
   'history':<Map<String,Object?>>[],
   'previousRules':<Map<String,Object?>>[],
   'cached':<Map<String,Object?>>[],
  });
  final waiting=(worker['waiting'] as List).cast<Map<String,Object?>>();
  expect(waiting,hasLength(1));
  expect((waiting.single['local'] as Map)['kind'],'expense');
  expect(worker['committed'],isEmpty);
  expect(worker['excluded'],isEmpty);
 });

 test('M1009 explicit exclusion learns repeatable service notice without numeric refs',(){
  const first='عزيزنا المالك/المفوض للمنشأة مؤسسة معادن '
    'المنتهية برقم 8219 نشعركم بصدور مديونية 2611447992';
  const second='عزيزنا المالك/المفوض للمنشأة شركة خالد '
    'المنتهية برقم 6290 نشعركم بصدور مديونية 881122';
  final rule=WaffraSmsLocalRules.suggestedGlobalRule(
   body:first,sender:'Etimad',kind:'excluded');
  expect(rule,isNotNull);
  expect(rule!.sender,isEmpty);
  expect(rule.autoPost,isFalse);
  expect(rule.keywords.any((v)=>RegExp(r'[0-9]').hasMatch(v)),isFalse);
  expect(WaffraSmsLocalRules.matches(rule,second,sender:'OtherSender'),isTrue);
  final posted='تم خصم SAR 30.00 نشعركم بصدور عملية تخص المالك';
  final matched=WaffraSmsLocalRules.matchAllFourKinds(
   body:posted,sender:'OtherSender',custom:[rule]);
  expect(WaffraSmsLocalRules.resolveSpecial(body:posted,
   sender:'OtherSender',bankKind:WaffraBankOperationKind.expense,
   custom:[rule],matchedRules:matched)?.resolvedKind,isNot('excluded'),
   reason:'Posted money must never be auto-excluded');
 });

 testWidgets('M1009 swipe on ACTUAL Notifications center changes visible sender',
  (tester)async{
  final notifications=[
   const WaffraReviewNotice(id:'a',sender:'Etimad',preview:'Debt notice only'),
   const WaffraReviewNotice(id:'b',sender:'AlRajhiBank',preview:'Purchase only'),
   const WaffraReviewNotice(id:'c',sender:'AlinmaPay',preview:'Incoming only'),
  ];
  await tester.pumpWidget(MaterialApp(home:WaffraApprovedNotificationsPage(
   english:false,readPending:()=>notifications,onReviewAll:()async{},
   onReviewOne:(_)async{},onRescan:()async{},canRescan:()=>true,
   onBulkExclude:(_,__)async=>true,
  )));
  final surface=find.byKey(const Key('m1009-notifications-sender-swipe'));
  expect(surface,findsOneWidget);
  expect(find.text('Debt notice only'),findsOneWidget);
  expect(find.text('Purchase only'),findsOneWidget);
  await tester.drag(surface,const Offset(-300,0));
  await tester.pumpAndSettle();
  expect(find.text('Debt notice only'),findsOneWidget);
  expect(find.text('Purchase only'),findsNothing);
  await tester.tap(find.byKey(const Key('m589-open-bulk-sms-review')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('m592-select-all-visible')));
  await tester.pump();
  expect(find.text('المحدد: 1'),findsOneWidget);
  await tester.drag(surface,const Offset(-250,0));
  await tester.pumpAndSettle();
  expect(find.text('Purchase only'),findsOneWidget);
  expect(find.text('Debt notice only'),findsNothing);
  expect(find.text('المحدد: 1'),findsOneWidget);
  await tester.drag(surface,const Offset(250,0));
  await tester.pumpAndSettle();
  expect(find.text('Debt notice only'),findsOneWidget);
  expect(find.text('المحدد: 1'),findsOneWidget);
 });
}
