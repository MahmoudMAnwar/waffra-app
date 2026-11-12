import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

void main() {
  const excluded = WaffraSmsLocalRule(
    id:'otp-exclude',name:'OTP',kind:'excluded',
    income:false,category:'',sender:'AlRajhiBank',
    keywords:['رمز التفعيل'],
  );
  test('matching excluded OTP rules keep masked SMS out of review', () {
    WaffraSmsLocalRules.validate(excluded);
    const masked='رمز التفعيل الخاص بك هو •••• لا تشارك الرمز';
    expect(WaffraSmsLocalRules.matches(
      excluded,masked,sender:'AlRajhiBank'),isTrue);
    expect(WaffraSmsLocalRules.resolveSpecial(
      body:masked,sender:'AlRajhiBank',
      bankKind:WaffraBankOperationKind.uncertain,
      custom:[excluded])?.resolvedKind,'excluded');
    expect(WaffraSmsLocalRules.matches(
      excluded,masked,sender:'UnrelatedSender'),isFalse);
  });

  test('an exclusion rule never automatically hides verified bank expenses',(){
    const expense='شراء بمبلغ 120.00 ريال رمز التفعيل لا يخصم تلقائيًا';
    expect(WaffraSmsLocalRules.resolveSpecial(
      body:expense,sender:'AlRajhiBank',
      bankKind:WaffraBankOperationKind.expense,
      custom:[excluded]),isNull);
  });

  test('Android history scans are bounded by a durable cursor', () {
    final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
    final code=native.split('fun importConsentMonth(')[1].split(
      '/** Claim each review notification once')[0];
    expect(code,contains('(date > ? OR (date = ? AND _id > ?)) AND date < ?'));
    expect(code,contains('historyCursorAt'));
    expect(code,contains('historyCursorId'));
    expect(code,contains('date ASC, _id ASC'));
    expect(code,contains('if (queue.length() >= maxCandidates)'));
    expect(code,contains('val queue = read(context)'));
    expect(code,contains('rows.size <= maxRead'));
    expect(code,contains('editor.putString(queueName, seal(queue.toString()))'));
    expect(code,contains('.putBoolean(historyComplete, complete)'));
    expect(code,contains('editor.commit()'));
  });

  test('native history scanning does not block Android UI thread',(){
    final activity=File('native/WaffraMainActivity.kt').readAsStringSync();
    expect(activity,contains('Executors.newSingleThreadExecutor()'));
    expect(activity,contains('smsHistoryExecutor.execute {'));
    expect(activity,contains('WaffraAutoSmsStore.importConsentMonth(app)'));
    expect(activity,contains('runOnUiThread { result.success(imported) }'));
    expect(activity,contains('smsHistoryExecutor.shutdown()'));
  });

  test('review refresh serializes work and batches durable exclusions',(){
    final app=File('lib/main.dart').readAsStringSync();
    expect(app,contains('Future<void>? _autoSmsRefreshInFlight;'));
    // The batch worker produces exclusion IDs; main retains only owner-
    // checked native ACK/rollback, rather than re-parsing 2k SMS on UI.
    expect(app,contains("final toAcknowledge=(classified['excluded'] as List).cast<String>();"));
    expect(app,contains('await compute(waffraM632ClassifySmsQueue,'));
    expect(app,contains('WaffraAutoSms.excludeMessages(batch)'));
    expect(app,contains('WaffraAutoSms.acknowledgeCommitted(batch)'));
    expect(app,isNot(contains('if(!await WaffraAutoSms.acknowledge(batch))')));
    expect(app,contains('toRestoreOnAckFailure'));
    expect(app,contains('setState(()=>_autoSmsPending.removeWhere'));
    // History is advanced only by the user's explicit Rescan. A bulk
    // exclusion must keep finance/review state fresh without surprise paging.
    final bulkStart=app.indexOf(' Future<void> _openAutoSmsInbox()async{');
    final bulkEnd=app.indexOf(' Widget _autoSmsReviewCard(){',bulkStart);
    expect(bulkStart,greaterThanOrEqualTo(0));
    expect(bulkEnd,greaterThan(bulkStart));
    final bulk=app.substring(bulkStart,bulkEnd);
    // Assert the actual guarded removal without imposing a whitespace layout:
    // this path intentionally wraps the setState callback across two lines.
    expect(bulk,contains('if(mounted)setState(()=>'));
    expect(bulk,contains('_autoSmsPending.removeWhere((row)=>done.contains(row[\'id\']))'));
    expect(bulk,contains('unawaited(_refreshAutoSmsInbox());'));
    expect(bulk,isNot(contains('importMonth:true')));
    final explicitRescan=app.substring(
      app.indexOf(' Future<void> _rescanAutoSmsInbox({BuildContext? feedbackContext})async{'),
      app.indexOf(' Future<void>? _autoSmsRefreshInFlight;'));
    expect(explicitRescan,contains('_refreshAutoSmsInbox(importMonth:true)'));
  });
}
