import 'dart:io';
import 'support/waffra_main_source.dart';

import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_source_method_section.dart';

void main(){
 test('M548 source guard ignores unrelated history import outside the method',(){
  const source='intro\n void review(){\n refresh();\n }\n'
   ' void next(){\n rescan(importMonth:true);\n }';
  final section=waffraSourceMethodSection(source,
   start:' void review(){',end:' void next(){');
  expect(section,contains('refresh();'));
  expect(section,isNot(contains('importMonth:true')));
 });

 test('M548 source guard fails closed when anchor disappears or duplicates',(){
  const source='void review(){} void next(){}';
  expect(()=>waffraSourceMethodSection(source,
   start:'// deleted comment',end:'void next(){}'),
   throwsFormatException);
  expect(()=>waffraSourceMethodSection(source,
   start:'void review(){}',end:'// missing next'),
   throwsFormatException);
  expect(()=>waffraSourceMethodSection(
    'void review(){} void review(){} void next(){}',
    start:'void review(){}',end:'void next(){}'),
   throwsFormatException);
  expect(()=>waffraSourceMethodSection(source,
   start:'void next(){}',end:'void review(){}'),
   throwsFormatException);
 });

 test('M548 source-contract tests cannot regress to comment slicing',(){
  final guard=File('test/m547_sms_incremental_jank_regression_test.dart')
   .readAsStringSync();
  expect(guard,contains('waffraSourceMethodSection('));
  expect(guard,isNot(contains(".split('//")));
  expect(guard,contains('start:\' Future<void> entrySheet('));
 });

 test('M548 explicit history paging belongs to Rescan, not review or rules',(){
  final main=readWaffraMainSourceForContracts();
  final review=waffraSourceMethodSection(main,
   start:' Future<void> _openAutoSmsInbox()async{',
   end:' Widget _autoSmsReviewCard(){');
  final rules=waffraSourceMethodSection(main,
   start:' Future<void> _openSmsRules({',
   end:' Future<void> _recordConfirmedSmsAccountAssociation({');
  final rescan=waffraSourceMethodSection(main,
   start:' Future<void> _rescanAutoSmsInbox({BuildContext? feedbackContext})async{',
   end:' Future<void>? _autoSmsRefreshInFlight;');
  expect(review,isNot(contains('importMonth:true')));
  expect(rules,isNot(contains('importMonth:true')));
  expect(review,contains('WaffraSmsReviewGroups.from(_autoSmsPending'));
  expect(review,contains('WaffraAutoSms.excludeMessages(batch)'));
  expect(review,contains('unawaited(_refreshAutoSmsInbox());'));
  expect(rules,contains('unawaited(_refreshAutoSmsInbox());'));
  expect(rescan,contains('await _refreshAutoSmsInbox(importMonth:true);'));
  // Explicit settings-triggered historical scan remains available.
  expect(main,contains('await WaffraAutoSms.importConsentMonth();'));
 });
}
