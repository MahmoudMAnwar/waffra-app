import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main() {
 test('M741 registered local SMS rule editor/learners retain original owner and money safety',(){
  final main=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_sms_rules.part.dart').readAsStringSync();
  expect(main,contains("part 'waffra_home_sms_rules.part.dart';"));
  expect(part,startsWith("part of 'main.dart';"));
  expect(part,contains('extension _WaffraHomeSmsRules on _HomeScreenState'));
  expect(main,isNot(contains(' Future<void> _openSmsRules(')));
  for(final marker in <String>[
   ' Future<void> _openSmsRules(',
   ' Future<void> _recordConfirmedSmsAccountAssociation(',
   ' Future<bool> _learnSafeSmsRule(',
   ' Future<void> _learnManualTransferPreference(',
   ' Future<void> _learnManualCategoryPreference(',
   'WaffraSmsLocalRules.resolveSpecial(',
   'WaffraSmsLocalRules.resolve(',
   'WaffraSmsCurrencies.requiresReviewForSarLedger(body)',
  ]) {
   expect(part,contains(marker),reason:marker);
  }
  expect(part,isNot(contains('_financeAuthority.saveCaptured(')));
  expect(part,isNot(contains('_financeAuthority.commitConfirmedSms(')));
  expect(main,contains(' Timer? _m632SmsNoticeTimer;'));
 });
 test('M741 previous safety contracts inspect the identical source from registered part',(){
  final restored=readWaffraMainSourceForContracts();
  final start=restored.indexOf(' Future<void> _openSmsRules(');
  final end=restored.indexOf(' Timer? _m632SmsNoticeTimer;',start);
  final part=File('lib/waffra_home_sms_rules.part.dart').readAsStringSync();
  final original=part.substring(part.indexOf(' Future<void> _openSmsRules('),
    part.lastIndexOf('\n}')+1);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  expect(restored.substring(start,end),original);
 });
}
