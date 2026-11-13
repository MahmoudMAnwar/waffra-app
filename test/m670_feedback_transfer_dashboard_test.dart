import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';

/// M670 regressions: owner-requested changes are presentation/navigation
/// only. Source routing tests guard zero/one-account finance safety; widget
/// tests exercise the shared notice across footer/fallback geometry.
void main() {
 for(final direction in <TextDirection>[
  TextDirection.rtl,TextDirection.ltr
 ]) {
  for(final width in <double>[320,393]) {
   testWidgets('M670 complete multi-line notice at ${width.toInt()}dp '
     '${direction.name} and 200% text', (tester) async {
    tester.view.physicalSize=Size(width,740);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const longMessage=
     'اكتمل فحص الرسائل البنكية؛ تم تحديث قائمة الرسائل التي تحتاج إلى '
     'مراجعة. هذه رسالة طويلة يجب عرضها كاملة دون قص النص أو زر إغلاق.';
    final notice=ValueNotifier<WaffraNoticeData?>(
     const WaffraNoticeData(text:longMessage,
      kind:WaffraSnackKind.success,duration:Duration(seconds:5),
      requireDismissal:true));
    addTearDown(notice.dispose);
    await tester.pumpWidget(MaterialApp(
     home:Directionality(textDirection:direction,
      child:MediaQuery(
       data:MediaQueryData(size:Size(width,740),
        textScaler:const TextScaler.linear(2)),
       child:Scaffold(
        body:const SizedBox.expand(),
        bottomNavigationBar:Column(
         mainAxisSize:MainAxisSize.min,children:[
          WaffraFooterNoticeHost(listenable:notice,
           onDismiss:()=>notice.value=null),
          const SizedBox(height:70),
         ]),
       ))),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(WaffraNoticeEdgeBody),findsOneWidget);
    expect(find.byKey(const Key('waffra-snackbar-close')),findsNothing);
    expect(find.text(longMessage),findsWidgets);
    expect(tester.getSize(find.byType(WaffraNoticeContent)).height,
     greaterThan(48));
    expect(tester.takeException(),isNull);
   });
  }
 }

 test('M670 SMS rescan feedback belongs to the requesting route',(){
  final main=File('lib/main.dart').readAsStringSync();
  final notifications=File('lib/waffra_approved_notifications.dart')
   .readAsStringSync();
  final rescan=main.split(
   ' Future<void> _rescanAutoSmsInbox({BuildContext? feedbackContext})async{')[1]
   .split(' Future<void>? _autoSmsRefreshInFlight;')[0];
  expect(main,contains(
   'onRescan:()=>_rescanAutoSmsInbox(feedbackContext:route),'));
  expect(notifications,contains(
   "key:const Key('m665-notification-pull-refresh')"));
  expect(rescan,contains('final feedback=feedbackContext??context;'));
  expect(rescan,contains("snackSuccess(feedback,waffraIsEnglish?"));
  expect(rescan,contains('لا توجد رسائل جديدة للمراجعة.'));
  expect(rescan,contains('تمت إضافة \$added رسالة جديدة للمراجعة.'));
  expect(rescan,isNot(contains('snackSuccess(context,')));
  expect(rescan,isNot(contains('snack(context,')));
 });

 test('M670 transfer always opens verified editor; second account is required',(){
  final main=File('lib/main.dart').readAsStringSync();
  final form=File('lib/waffra_account_transaction_form.dart')
   .readAsStringSync();
  final manual=main.split(' Future<void> openVerifiedTransfer()async{')[1]
   .split(' WaffraFinanceAuthorityRead? _lastFinanceAuthorityRead;')[0];
  final sms=main.split(' Future<void> _reviewSmsAccountTransfer({')[1]
   .split(' void _receiveSharedSms(){')[0];
  expect(manual,contains('WaffraAccountTransactionForm('));
  expect(manual,contains('initialOperation:WaffraAccountOperation.transfer'));
  expect(manual,contains('onCreateAccount:(group,createProvider)async{'));
  expect(manual,isNot(contains('accounts.where((a)=>!a.archived).length<2')));
  expect(sms,contains('initialSmsTransfer:prefill'));
  expect(sms,contains('onCreateSmsAccount:'));
  expect(sms,isNot(contains('facts.kind!=WaffraBankOperationKind.transfer||facts.pending')));
  expect(form,contains('destination==null||destination==source'));
  expect(form,contains('!active.any((a)=>a.id==destination)'));
 });

 test('M670 separate SMS alternative opens only selected income/expense editor',(){
  final source=File('lib/main.dart').readAsStringSync();
  final review=source.split(
   "   }else if(decision=='transfer-manual'&&mounted){")[1]
   .split("   }else if(decision=='yes'&&mounted")[0];
  final picker=source.split('    Widget operationPicker(){')[1]
   .split('    if(transferSelected){')[0];
  expect(review,contains('اختر نوع العملية التي تريد إضافتها:'));
  expect(review,contains("Navigator.pop(dialog,'income')"));
  expect(review,contains("Navigator.pop(dialog,'expense')"));
  expect(review,contains("await entrySheet(manualIncomeOverride:kind=='income',"));
  expect(review,contains('reviewedOriginalSms:body'));
  expect(review,isNot(contains('acknowledgeCommitted(')));
  expect(picker,contains('if(manualIncomeOverride!=null&&initial==null&&!sms)'));
  expect(picker,contains('return const SizedBox.shrink();'));
 });

 test('M670 all Home filters have a real limit and reversible expansion',(){
  final source=File('lib/main.dart').readAsStringSync();
  final dashboard=source.split(' Widget dashboard(){')[1]
   .split(' List<MoneyEntry> get analysisEntries')[0];
  for(final label in ['الكل','الدخل','المصروفات','التحويلات',
   'الادخار','الاستحقاقات']){
   expect(dashboard,contains("'$label'"));
  }
  expect(dashboard,contains(
   'waffraDashboardTransactionDisplayCount(\n               history.length,expanded:showAllTransactions)'));
  expect(dashboard,contains(
   'waffraCanExpandDashboardTransactions(history.length)'));
  expect(dashboard,contains("Key('waffra-dashboard-unified-activity-expand')"));
  expect(dashboard,contains("Key('waffra-dashboard-transactions-expand')"));
  expect(dashboard,contains('showAllTransactions=false;'));
 });

 test('M670 goals, recurring and category stats share layout geometry',(){
  final source=File('lib/main.dart').readAsStringSync();
  final cats=File('lib/waffra_categories_page.part.dart').readAsStringSync();
  expect(cats,contains('Widget _compactCategoryStat('));
  expect(source,contains("Key('m689-goal-card-'"));
  expect(source,contains(
   "Key('m689-due-card-'"));
  expect(source,contains("WaffraApprovedMetrics(metrics:["));
  expect(source,contains("_m689GoalActions(g)"));
  expect(source,contains("Key('m689-due-settings')"));
  expect(source,contains('Tooltip(message:waffraIsEnglish?'));
 });

 test('M670 Snackbar central presenter has no visible X nor 2-line clipping',(){
  final source=File('lib/main.dart').readAsStringSync();
  final body=source.split('class WaffraNoticeContent extends StatelessWidget')[1]
   .split('final ValueNotifier<WaffraNoticeData?> _waffraFooterNotice=')[0];
  expect(body,isNot(contains('waffra-snackbar-close')));
  expect(body,isNot(contains('maxLines:2')));
  // Message body wraps completely; the separate Undo chip may elide its
  // own short label without clipping the actual notice text.
  final messageBody=body.split('child:WaffraText(notice.text,')[1]
   .split('if(notice.onAction!=null)')[0];
  expect(messageBody,isNot(contains('TextOverflow.ellipsis')));
  expect(messageBody,isNot(contains('maxLines:')));
  expect(body,contains("Key('waffra-snackbar-action')"),
   reason:'Undo remains an explicit reversible action');
 });
}
