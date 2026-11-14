import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main() {
 test('M783 exact registered live native SMS settings and exclusions retain guarded logic',() {
  final home=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_sms_management.part.dart').readAsStringSync();
  expect(home,contains("part 'waffra_home_sms_management.part.dart';"));
  expect(part,startsWith("part of 'main.dart';"));
  expect(part,contains('extension _WaffraHomeSmsManagement on _HomeScreenState'));
  expect(home,isNot(contains(' Future<void> _scanPreviousBankSmsFromSettings()async{')));
  for(final symbol in <String>[
   ' Future<void> _scanPreviousBankSmsFromSettings()async{',
   ' Future<void> _openUnknownSmsFromSettings()async{',
   ' Future<void> _openExcludedSenders()async{',
   ' List<WaffraReviewNotice> _m549ReviewNotices(){',
   ' Future<bool> _m592ExcludeNotificationSelection(',
   ' Future<void> _m549OpenNotifications()async{',
   'WaffraAutoSms.excludedSenders()',
   'WaffraAutoSms.excludedMessages()',
   '_rescanAutoSmsInbox(feedbackContext:route)',
  ]) {
   expect(part,contains(symbol),reason:symbol);
  }
  expect(part,isNot(contains('_financeAuthority.saveCaptured(')));
  expect(part,isNot(contains('_financeAuthority.commitConfirmedSms(')));
  expect(home,contains(' Widget _autoSmsReviewCard(){'));
 });
 test('M783 old finance and SMS regression source reads the actual registered methods',() {
  final source=readWaffraMainSourceForContracts();
  final begin=source.indexOf(' Future<void> _scanPreviousBankSmsFromSettings()async{');
  final end=source.indexOf(' // M739: original sender-grouped bank SMS inbox dialog',begin);
  final part=File('lib/waffra_home_sms_management.part.dart').readAsStringSync();
  final original=part.substring(part.indexOf(' Future<void> _scanPreviousBankSmsFromSettings()async{'),
    part.lastIndexOf('\n}')+1);
  expect(begin,greaterThan(0));
  expect(end,greaterThan(begin));
  expect(source.substring(begin,end),original);
 });
}
