import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_messages.dart';

void main(){
 const fingerprint='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

 test('M621 Android target accepts only opaque IDs and explicit route',(){
  final review=WaffraFinanceNotificationTarget.parse({
   'destination':'review','id':fingerprint,
  });
  expect(review?.destination,'review');
  expect(review?.id,fingerprint);
  expect(review?.entryId,isNull);
  final saved=WaffraFinanceNotificationTarget.parse({
   'destination':'saved','id':fingerprint,'entryId':'synthetic_ledger_1',
  });
  expect(saved?.destination,'saved');
  expect(saved?.entryId,'synthetic_ledger_1');
  expect(WaffraFinanceNotificationTarget.parse({
   'destination':'saved','id':fingerprint,
  }),isNull);
  expect(WaffraFinanceNotificationTarget.parse({
   'destination':'saved','id':fingerprint,'entryId':'bad\nnewline',
  }),isNull);
  expect(WaffraFinanceNotificationTarget.parse({
   'destination':'review','id':'bad',
  }),isNull);
  expect(WaffraFinanceNotificationTarget.parse({
   'destination':'delete','id':fingerprint,
  }),isNull);
  expect(WaffraFinanceNotificationTarget.parse('raw sms'),isNull);
 });

 test('M620 small icon is real transparent 24dp white wallet drawable',(){
  final icon=File('native/waffra_notification_wallet.xml').readAsStringSync();
  expect(icon,contains('android:width="24dp"'));
  expect(icon,contains('android:height="24dp"'));
  expect(icon,contains('android:strokeColor="#FFFFFFFF"'));
  expect(icon,contains('android:fillColor="@android:color/transparent"'));
  for(final path in [
   '.github/workflows/android.yml',
   '.github/workflows/android-full-smoke.yml',
  ]){
   expect(File(path).readAsStringSync(),
    contains("native/waffra_notification_wallet.xml"));
  }
  final native=File('native/WaffraAutoSmsNotifications.kt').readAsStringSync();
  expect(native,contains('R.drawable.waffra_notification_wallet'));
  expect(native,isNot(contains('android.R.drawable.ic_dialog_info')));
 });

 test('M620 review proposals are not misleading financial save claims',(){
  final native=File('native/WaffraAutoSmsNotifications.kt').readAsStringSync();
  expect(native,contains('دخل مقترح للمراجعة'));
  expect(native,contains('مصروف مقترح للمراجعة'));
  expect(native,contains('تحويل مقترح للمراجعة'));
  expect(native,contains('وفرة — عملية تحتاج مراجعة'));
  final worker=File('lib/waffra_auto_sms_autopost.part.dart').readAsStringSync();
  expect(worker,contains('await WaffraAutoSms.notifyReview(id,kind:kind)'));
  expect(worker,contains('WaffraBankOperationKind.transfer'));
  expect(worker,contains('if(committed.saved==1&&persisted&&'));
  expect(worker,contains('linkedBudget:false,entryId:entry.id'));
 });

 test('M621 unique PendingIntent survives background start without SMS extras',(){
  final native=File('native/WaffraAutoSmsNotifications.kt').readAsStringSync();
  expect(native,contains('data = Uri.parse("waffra-finance://'));
  expect(native,contains('PendingIntent.FLAG_IMMUTABLE'));
  expect(native,contains('putExtra(EXTRA_SMS_ID, fingerprint)'));
  expect(native,contains('setContentIntent(openPending(context, fingerprint, "review"))'));
  expect(native,contains('openPending(context, fingerprint, "saved", entryId)'));
  final activity=File('native/WaffraMainActivity.kt').readAsStringSync();
  expect(activity,contains('receiveFinanceNotification(intent)'));
  expect(activity,contains('override fun onNewIntent(intent: Intent)'));
  expect(activity,contains('"takeFinanceNotificationTap"'));
  expect(activity,contains('pendingFinanceNotification = payload'));
  final messages=File('lib/waffra_messages.dart').readAsStringSync();
  expect(messages,contains("call.method=='financeNotificationTap'"));
  expect(messages,contains("'takeFinanceNotificationTap'"));
 });

 test('M621 taps cannot bypass verified Home or book a second transaction',(){
  final home=File('lib/main.dart').readAsStringSync();
  final segment=home.split(' void _m621OnFinanceNoticeTap(){')[1]
   .split(' @override void dispose(){')[0];
  expect(segment,contains('!ready||_financeLoadFailure!=null'));
  expect(segment,contains('AppLifecycleState.resumed'));
  expect(segment,contains('await _reviewAutoSmsCandidates(targetId:target.id)'));
  expect(segment,contains("record.id==target.entryId&&record.sourceType=='sms'"));
  expect(segment,contains('await transactionDetails(matching.single)'));
  expect(segment,isNot(contains('commitConfirmedSms(')));
  expect(home,contains('waffraFinanceNoticeTap.addListener(_m621OnFinanceNoticeTap)'));
  expect(home,contains('waffraFinanceNoticeTap.removeListener(_m621OnFinanceNoticeTap)'));
  final review=home.split(' Future<void> _reviewAutoSmsCandidates({String? targetId})async {')[1]
   .split(' void _receiveSharedSms(){')[0];
  expect(review,contains('WaffraAutoSms.pendingById(targetId)'));
  expect(review,contains("decision=='yes'"));
  expect(review,contains("decision=='no'"));
  expect(review,contains("decision=='exclude'"));
  expect(review,contains('if(mounted&&waffraFinanceNoticeTap.value!=null)'));
  final manual=home.split(' Future<void> bulkSmsSheet({String? initialText')[1]
   .split(' Future<void> _previewForeignBankCurrency(String raw)async {')[0];
  expect(manual,contains('if(mounted&&waffraFinanceNoticeTap.value!=null)'));
 });
}
