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
    expect(code,contains('if (queued >= maxCandidates || checked >= maxRead)'));
    expect(code,contains('putBoolean(historyComplete, complete).commit()'));
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
    expect(app,contains('final toAcknowledge=<String>[];'));
    expect(app,contains('WaffraAutoSms.acknowledge(toAcknowledge)'));
    expect(app,contains('toRestoreOnAckFailure'));
    expect(app,contains('setState(()=>_autoSmsPending.removeWhere'));
    expect(app,contains('unawaited(_refreshAutoSmsInbox(importMonth:true))'));
  });
}
