import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// M964: source-only boundary check, alongside existing first-frame,
/// historical finance and SMS tests. No private user data.
void main(){
 test('M964 Home pure helpers keep their signatures and exact owner scope '
      'in one registered same-library part',(){
  final main=File('lib/main.dart').readAsStringSync();
  final helper=File('lib/waffra_home_state_core_helpers.part.dart')
    .readAsStringSync();
  expect(main,contains("part 'waffra_home_state_core_helpers.part.dart';"));
  expect(helper,startsWith("part of 'main.dart';"));
  for(final symbol in const [
    'bool _m630SmsSessionCurrent(int epoch)=>',
    'String get _m467ChoiceKey{',
    'WaffraFinancePeriodIndex get _m684Periods=>',
    'String get _smsRuleOwnerKey=>',
  ]){
   expect(helper,contains(symbol));
   expect(main,isNot(contains(symbol)));
  }
  expect(helper,contains('epoch==_m630HomeStartupEpoch'));
  expect(helper,contains("sha256.convert(utf8.encode(owner)).toString()"));
  expect(helper,contains('_m940LedgerReads.index(entries)'));
  expect(helper,contains('WaffraSmsLocalRuleStore.ownerKey('));
  // Session-bound callback identity, first-frame flow, finance invalidation,
  // consent and disposal deliberately remain owned by Home State.
  expect(main,contains('void _receiveSharedSms(){'));
  expect(main,contains('void _m684InvalidatePeriodRead(){'));
  expect(main,contains('Future<bool> _m528SmsEnabled()=>'));
  expect(main,contains('@override void dispose(){'));
  expect(main,contains('@override void initState(){'));
  expect(main,contains('@override Widget build(BuildContext context)=>'));
 });
}
