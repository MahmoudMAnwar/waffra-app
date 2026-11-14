import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main() {
 test('M739 real sender-grouped SMS inbox is registered once without changing finance paths', () {
  final main=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_sms_inbox.part.dart').readAsStringSync();
  expect(main,contains("part 'waffra_home_sms_inbox.part.dart';"));
  expect(part,startsWith("part of 'main.dart';"));
  expect(part,contains('extension _WaffraHomeSmsInbox on _HomeScreenState'));
  expect(main,isNot(contains(' Future<void> _openAutoSmsInbox()async{')));
  expect(part,contains(' Future<void> _openAutoSmsInbox()async{'));
  expect(part,contains('WaffraSmsReviewGroups.from('));
  expect(part,contains('selectedSender'));
  expect(part,contains('selectedIds'));
  expect(part,contains("key:Key('waffra-sms-select-message-'"));
  expect(part,contains('_reviewAutoSmsCandidates('));
  expect(part,contains('لن تُسجَّل أي عملية مالية إلا بعد مراجعتك وتأكيدك.'));
  expect(part,isNot(contains('_financeAuthority.saveCaptured(')));
  expect(part,isNot(contains('_financeAuthority.commitConfirmedSms(')));
  expect(readWaffraMainSourceForContracts(),contains(' Widget _autoSmsReviewCard(){'));
 });
 test('M739 previous Home source contracts read the exact authenticated inbox part', () {
  final whole=readWaffraMainSourceForContracts();
  final start=whole.indexOf(' Future<void> _openAutoSmsInbox()async{');
  final end=whole.indexOf(' // ignore: unused_element\n Widget _autoSmsReviewCard(){',start);
  final part=File('lib/waffra_home_sms_inbox.part.dart').readAsStringSync();
  final original=part.substring(part.indexOf(' Future<void> _openAutoSmsInbox()async{'),
    part.lastIndexOf('\n}')+1);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  expect(whole.substring(start,end),original);
 });
}
