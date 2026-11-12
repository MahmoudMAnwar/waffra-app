import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

// Issue #589: a saved, sender-scoped manual rule and a single excluded SMS
// are different operations. These tests preserve financial fail-closed guards.
void main() {
 group('M661 manual excluded rule application', () {
  const rule = WaffraSmsLocalRule(
   id: 'custom_m661_beneficiary_added',
   name: 'إضافة مستفيد',
   kind: 'excluded',
   keywords: ['تمت اضافة المستفيد'],
   income: false,
   category: '',
   sender: 'AlRajhiBank',
   matchAll: false,
  );

  test('rule is valid, durable and matches same-sender name variants', () {
   const first = 'تمت اضافة المستفيد: محمد صابر خليل محمد';
   const second = 'تمت إضافة المستفيد: أحمد علي';
   WaffraSmsLocalRules.validate(rule);
   expect(rule.autoPost, isFalse);
   for (final message in [first, second]) {
    final bank = WaffraBankSmsFactsParser.parse(message);
    expect(bank.kind, WaffraBankOperationKind.uncertain);
    final matched = WaffraSmsLocalRules.resolveSpecial(
     body: message,
     sender: 'AlRajhiBank',
     bankKind: bank.kind,
     custom: const [rule],
    );
    expect(matched?.id, rule.id);
    expect(matched?.resolvedKind, 'excluded');
   }
   expect(rule.toJson().toString(), isNot(contains('محمد صابر')));
  });

  test('other bank sender cannot inherit a manual excluded rule', () {
   const message = 'تمت إضافة المستفيد: أحمد علي';
   expect(WaffraSmsLocalRules.matches(
    rule, message, sender: 'OtherBank'), isFalse);
   final result = WaffraSmsLocalRules.resolveSpecial(
    body: message, sender: 'OtherBank',
    bankKind: WaffraBankSmsFactsParser.parse(message).kind,
    custom: const [rule],
   );
   expect(result?.id, isNot(rule.id));
  });

  test('posted financial transfer is never excluded by beneficiary phrase', () {
   const message =
    'تحويل بين حسابات بمبلغ 100 ريال، تمت إضافة المستفيد: أحمد علي';
   final facts = WaffraBankSmsFactsParser.parse(message);
   expect(facts.kind, WaffraBankOperationKind.transfer);
   final special = WaffraSmsLocalRules.resolveSpecial(
    body: message, sender: 'AlRajhiBank', bankKind: facts.kind,
    custom: const [rule],
   );
   expect(special?.resolvedKind, isNot('excluded'));
  });

  test('single beneficiary notice exclusion does not silently learn M660', () {
   final candidate = WaffraSmsLocalRules.suggestedRule(
    body: 'تمت إضافة المستفيد: محمد صابر خليل محمد',
    sender: 'AlRajhiBank', kind: 'excluded', confidentOnly: true,
   );
   expect(candidate, isNull,
    reason: 'M660 structural template learning is not implemented in M661');
  });
 });

 group('M661 source and routing safety contract', () {
  test('every successful manual create/edit/delete signals rule refresh', () {
   final source = File('lib/waffra_sms_rule_settings_page.dart')
    .readAsStringSync();
   final home = File('lib/main.dart').readAsStringSync();
   expect(source, contains('final VoidCallback? onRulesChanged;'));
   final persist = source.substring(
    source.indexOf(' Future<bool> _persist('),
    source.indexOf(' Future<void> _remove('),
   );
   final storeWrite = persist.indexOf('await store.write(widget.ownerKey,next)');
   final signal = persist.indexOf('widget.onRulesChanged?.call()');
   expect(storeWrite, greaterThanOrEqualTo(0));
   expect(signal, greaterThan(storeWrite));
   expect(home, contains('onRulesChanged:()=>_receiveAutoSmsNotice()'));
   expect(home, contains('unawaited(_refreshAutoSmsInbox())'));
   expect(home, contains('await compute(waffraM632ClassifySmsQueue'));
  });

  test('manual sender preview uses paired live sender IDs', () {
   final source = File('lib/waffra_sms_rule_settings_page.dart')
    .readAsStringSync();
   final home = File('lib/main.dart').readAsStringSync();
   expect(source, contains('final List<String> scannedSenders;'));
   expect(source, contains('widget.scannedMessages.asMap().entries.where'));
   expect(source, contains('widget.scannedSenders[row.key]'));
   expect(home, contains('scannedSenders:_autoSmsPending.map((row)=>'));
  });

  test('unreadable encrypted rules do not silently look like saved matching rules', () {
   final home = File('lib/main.dart').readAsStringSync();
   final begin = home.indexOf('  var customRules=<WaffraSmsLocalRule>[];');
   final end = home.indexOf('  final classified=await compute(', begin);
   expect(begin, greaterThanOrEqualTo(0));
   expect(end, greaterThan(begin));
   final refresh = home.substring(begin,end);
   expect(refresh, contains('_m661RuleLoadErrorNotified'));
   expect(refresh, contains('isError:true'));
   expect(refresh, contains('قواعد الاستبعاد المضافة غير نشطة'));
   expect(home, contains('لم يتم تعلّم قاعدة للرسائل المشابهة'));
  });

  test('queued custom exclusions use durable native IDs, never finance writes', () {
   final home = File('lib/main.dart').readAsStringSync();
   final start = home.indexOf(
    'Map<String,Object?> waffraM632ClassifySmsQueue(');
   final end = home.indexOf('List<String> splitBankMessages(', start);
   expect(start, greaterThanOrEqualTo(0));
   expect(end, greaterThan(start));
   final isolate = home.substring(start,end);
   expect(isolate, contains(
    "local['kind']=='excluded'&&local['defaultSeed']!=true"));
   expect(isolate, contains('excluded.add(id)'));
   expect(isolate, isNot(contains('commitConfirmedSms(')));
   final native = File('native/WaffraAutoSmsStore.kt').readAsStringSync();
   expect(native, contains('fun excludeMessages(context: Context, ids: Set<String>)'));
   // The native exclusion batch checks each requested fingerprint using `it`,
   // never accepting an ID unless it is queued or already excluded.
   expect(native, contains('!isExcludedMessageLocked(context, it)'));
   expect(native, contains('excludedLabelRetentionMs = 30L * 24 * 60 * 60 * 1000'));
  });
 });
}
