import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

/// M982 (#687): synthetic application and rules; no Android phone, SMS or
/// real banking records. Verify method-routing and owner's safety boundary.
void main() {
  test('M982 Flutter background calls the same native exclusion method as Home',
      () {
    final flutter=File('lib/waffra_auto_sms.dart').readAsStringSync();
    final live=File('native/WaffraMainActivity.kt').readAsStringSync();
    final worker=File('native/WaffraAutoSmsWorker.kt').readAsStringSync();
    final poster=File('lib/waffra_auto_sms_autopost.part.dart')
      .readAsStringSync();
    expect(flutter,contains("return _boolCall('excludeAutoBankSms',ids);"));
    final liveStart=live.indexOf('"excludeAutoBankSms" -> {');
    final liveEnd=live.indexOf('"ackCompletedTransferAutoBankSms" ->',liveStart);
    expect(liveStart,greaterThanOrEqualTo(0));
    expect(liveEnd,greaterThan(liveStart));
    final liveCase=live.substring(liveStart,liveEnd);
    expect(liveCase,contains('WaffraAutoSmsStore.excludeMessages(app, ids)'));
    final workerStart=worker.indexOf('"excludeAutoBankSms" -> {');
    final workerEnd=worker.indexOf('"ackCommittedAutoBankSms" ->',workerStart);
    expect(workerStart,greaterThanOrEqualTo(0));
    expect(workerEnd,greaterThan(workerStart));
    final workerCase=worker.substring(workerStart,workerEnd);
    expect(workerCase,contains('val ids = (call.arguments as? List<*>)'));
    expect(workerCase,contains('?.filterIsInstance<String>()?.toSet() ?: emptySet()'));
    expect(workerCase,contains(
      'result.success(WaffraAutoSmsStore.excludeMessages(context, ids))'));
    expect(workerCase,isNot(contains('acknowledgeCommitted(')));
    expect(workerCase,isNot(contains('acknowledge(context,')));
    expect(workerCase,isNot(contains('commitConfirmedSms(')));
    expect(poster,contains('await WaffraAutoSms.excludeMessages([id])'));
    expect(poster,contains("if(rule?.resolvedKind=='excluded'){"));
  });

  test('M982 saved owner rule and default rule both exclude on background',
      () {
    const custom=WaffraSmsLocalRule(
      id:'m982_app_activation',name:'App activation',kind:'excluded',
      income:false,category:'',sender:'NewApp',
      keywords:['تفعيل الحساب'],matchAll:false);
    const body='تفعيل الحساب لتطبيق تجريبي جديد';
    final matched=WaffraSmsLocalRules.matchAllFourKinds(
      body:body,sender:'NewApp',custom:const [custom]);
    expect(matched.map((r)=>r.id),contains(custom.id));
    final result=WaffraSmsLocalRules.resolveSpecial(
      body:body,sender:'NewApp',
      bankKind:WaffraBankSmsFactsParser.parse(body).kind,
      matchedRules:matched,custom:const [custom]);
    expect(result?.resolvedKind,'excluded');
    expect(result?.autoPost,isFalse);
    final other=WaffraSmsLocalRules.matchAllFourKinds(
      body:body,sender:'OtherApp',custom:const [custom]);
    expect(other.where((r)=>r.id==custom.id),isEmpty);
    final promo='عرض حصري لك اليوم';
    final builtIn=WaffraSmsLocalRules.resolveSpecial(
      body:promo,sender:'NewApp',
      bankKind:WaffraBankOperationKind.uncertain,
      matchedRules:WaffraSmsLocalRules.matchAllFourKinds(
        body:promo,sender:'NewApp'));
    expect(builtIn?.resolvedKind,'excluded');
  });

  test('M982 no completed money or SMS secret travels through background exclusion',
      () {
    final store=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
    final start=store.indexOf(
      'fun excludeMessages(context: Context, ids: Set<String>): Boolean');
    final end=store.indexOf(
      'fun acknowledgeCompletedTransfer(context: Context, ids: Set<String>): Boolean',
      start);
    expect(start,greaterThanOrEqualTo(0));
    expect(end,greaterThan(start));
    final block=store.substring(start,end);
    expect(block,contains('if (!enabled(context) || ids.isEmpty() || ids.size > 100 ||'));
    expect(block,contains('!isExcludedMessageLocked(context, it)'));
    expect(block,contains('excludedMessageBucketPrefix + bucket'));
    expect(block,contains('excludedMessageInfoBucketPrefix + bucket'));
    expect(block,contains('.put("id", fingerprint)'));
    expect(block,contains('.put("sender", row.optString("sender").take(100))'));
    expect(block,contains('.put("excludedAt", System.currentTimeMillis())'));
    expect(block,contains('.commit()'));
    expect(block,isNot(contains('.put("body"')));
    expect(block,isNot(contains('acknowledgeCommitted(')));
    expect(block,isNot(contains('commitConfirmedSms(')));
    expect(store,contains('excludedLabelRetentionMs = 30L * 24 * 60 * 60 * 1000'));
  });
}
