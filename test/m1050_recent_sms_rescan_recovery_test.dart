import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Issue #782: manual notification pull must recover late/backdated Android
/// provider rows without rewinding the normal durable history cursor.
void main() {
  test('M1050 recent SMS recovery scans provider behind the high-water mark', () {
    final native = File('native/WaffraAutoSmsStore.kt').readAsStringSync();
    final start = native.indexOf('fun recoverRecentlyMissedSms(');
    final end = native.indexOf('fun importConsentMonth(', start);
    expect(start, greaterThan(0));
    expect(end, greaterThan(start));
    final method = native.substring(start, end);
    expect(method, contains('fun recoverRecentlyMissedSms('));
    expect(method, contains('installationMonthStart(context)'));
    expect(method, contains('7L * 24L * 60L * 60L * 1000L'));
    expect(method, contains('Uri.parse("content://sms/inbox")'));
    expect(method, contains('"date >= ? AND date < ?"'));
    expect(method, contains('"date DESC, _id DESC"'));
    // No high-water date/id predicates; no destructive source reset.
    expect(method, isNot(contains('historyCursorAt')));
    expect(method, isNot(contains('historyCursorId')));
    expect(method, isNot(contains('restartCompletedHistory')));
    expect(method, isNot(contains('remove(queueName)')));
    expect(method, contains('ownerAtStart != signedInOwnerHash(context)'));
    expect(method, contains('historical = true'));
    expect(method, contains('offer(context, sender, body, identityAt,'));
    // All known-source dedupe, individual sender exclusions, pure OTP filtering,
    // and verified finance proof remain in the already-shared offer() gate.
    final live = native.substring(
      native.indexOf('fun offer(context: Context,'),
      native.indexOf('fun pending(context: Context):'));
    expect(live, contains('isExcludedLocked(context, sender)'));
    expect(live, contains('isCommittedLocked(context, fingerprint)'));
    expect(live, contains('isExcludedMessageLocked(context, fingerprint)'));
    expect(live, contains('isCompletedTransferLocked(context, fingerprint)'));
    expect(live, contains('pureVerificationOnly(body)'));
  });

  test('M1050 pull calls safe recovery then refreshes owner queue with truthful partial warning', () {
    final dart = File('lib/waffra_auto_sms.dart').readAsStringSync();
    final activity = File('native/WaffraMainActivity.kt').readAsStringSync();
    final rescan = File('lib/waffra_home_sms_rescan.part.dart').readAsStringSync();
    expect(dart, contains('recoverRecentlyMissedSmsChecked()'));
    expect(dart, contains("'recoverRecentlyMissedBankSms'"));
    expect(activity, contains('"recoverRecentlyMissedBankSms" -> {'));
    expect(activity, contains('smsHistoryExecutor.execute {'));
    expect(activity, contains('WaffraAutoSmsStore.recoverRecentlyMissedSms(app)'));
    expect(rescan, contains('await _refreshAutoSmsInbox(importMonth:true);'));
    expect(rescan, contains('await WaffraAutoSms.recoverRecentlyMissedSmsChecked();'));
    expect(rescan, contains('await _refreshAutoSmsInbox();'));
    expect(rescan, contains("recovery['partial']==true"));
    expect(rescan, contains("recovery['capacityBlocked']==true"));
    expect(rescan, contains('SMS_RESCAN_RECOVERY'));
    // A notification swipe is still a real scan, not a purely visual reload.
    final ui = File('lib/waffra_approved_notifications.dart').readAsStringSync();
    expect(ui, contains('await run(widget.onRescan);'));
  });

  test('M1050 recovery rejects missing provider and respects bounded 1000-row review capacity', () {
    final src = File('native/WaffraAutoSmsStore.kt').readAsStringSync();
    final method = src.substring(
      src.indexOf('fun recoverRecentlyMissedSms('),
      src.indexOf('fun importConsentMonth(',src.indexOf('fun recoverRecentlyMissedSms(')));
    expect(method, contains('throw IllegalStateException("SMS_RECOVERY_PROVIDER_UNAVAILABLE")'));
    expect(method, contains('maxCandidates'));
    expect(method, contains('maxRead'));
    expect(method, contains('"partial" to'));
    expect(method, contains('"capacityBlocked" to'));
    expect(method, isNot(contains('acknowledgeCommitted(')));
    expect(method, isNot(contains('excludeMessages(')));
    expect(method, isNot(contains('finance')));
  });
}
