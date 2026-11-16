import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_background_checkpoint.dart';

void main(){
 test('M1023 notification-denied reviews remain available but do not hot-loop',(){
  final pending=<Map<String,Object?>>[
   {'id':'a','backgroundAttempted':true,
    'backgroundRuleRevision':'r','backgroundNotificationPending':true,
    'backgroundNotificationRetryAt':100000},
   {'id':'b','backgroundAttempted':false}
  ];
  final noPermission=WaffraSmsBackgroundCheckpoint.select(pending,
   currentRulesRevision:'r',notificationsAllowed:false,nowMilliseconds:200000);
  expect(noPermission.candidates.map((x)=>x['id']),['b']);
  final retryTooSoon=WaffraSmsBackgroundCheckpoint.select(pending,
   currentRulesRevision:'r',notificationsAllowed:true,nowMilliseconds:99000);
  expect(retryTooSoon.candidates.map((x)=>x['id']),['b']);
  final canRetry=WaffraSmsBackgroundCheckpoint.select(pending,
   currentRulesRevision:'r',notificationsAllowed:true,nowMilliseconds:200000);
  expect(canRetry.candidates.map((x)=>x['id']),['a','b']);
 });
 test('M1023 Android records review-notified only after attempting native display',(){
  final src=File('native/WaffraAutoSmsNotifications.kt').readAsStringSync();
  final method=src.split('    fun notifyReview(context: Context, fingerprint: String')[1];
  expect(method,contains('WaffraAutoSmsStore.reviewNotificationClaimed(context, fingerprint)'));
  expect(method,contains('if (alreadyDelivered) return true'));
  expect(method.indexOf('manager(context).notify('),
   lessThan(method.indexOf('WaffraAutoSmsStore.claimReviewNotification(context, fingerprint)')));
  final store=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  expect(store,contains('fun reviewNotificationClaimed(context: Context, fingerprint: String): Boolean?'));
 });
 test('M1023 failed review notification stores retry state inside encrypted SMS',(){
  final store=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  expect(store,contains('"backgroundNotificationPending" to row.optBoolean("backgroundNotificationPending", false)'));
  expect(store,contains('"backgroundNotificationRetryAt" to row.optLong("backgroundNotificationRetryAt", 0L)'));
  expect(store,contains('row.put("backgroundNotificationPending", !delivered)'));
  expect(store,contains('row.put("backgroundNotificationRetryAt", if (delivered) 0L'));
  expect(store,contains('WaffraAutoSmsStore.markBackgroundSmsReviewed(context, id, revision, delivered)')==false,isTrue);
  final worker=File('native/WaffraAutoSmsWorker.kt').readAsStringSync();
  expect(worker,contains('args?.get("delivered") == true'));
  expect(worker,contains('"canNotifyBankSms" ->'));
  final dart=File('lib/waffra_auto_sms_autopost.part.dart').readAsStringSync();
  expect(dart,contains('notificationDelivered:delivered'));
  expect(dart,contains('notificationsAllowed:notificationsAllowed'));
 });
}
