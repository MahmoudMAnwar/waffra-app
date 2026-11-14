import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main() {
 test('M742 registered native SMS refresh retains exact owner and no-auto-post checks',(){
  final main=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_sms_refresh.part.dart').readAsStringSync();
  expect(main,contains("part 'waffra_home_sms_refresh.part.dart';"));
  expect(part,startsWith("part of 'main.dart';"));
  expect(part,contains('extension _WaffraHomeSmsRefresh on _HomeScreenState'));
  expect(main,isNot(contains(' Future<void> _runAutoSmsRefresh(')));
  expect(part,contains(' Future<void> _refreshAutoSmsInbox('));
  expect(part,contains(' Future<void> _runAutoSmsRefresh('));
  expect(part,contains('WaffraAutoSms.pendingChecked()'));
  expect(part,contains('WaffraAutoSms.trackingStatus()'));
  expect(part,contains('_m630SmsSessionCurrent(smsEpoch)'));
  expect(part,contains('compute(waffraM632ClassifySmsQueue,'));
  expect(part,contains('toAcknowledgeCommitted'));
  expect(part,contains('WaffraAutoSms.acknowledgeCommitted('));
  expect(part,contains('Passive SMS review is local-only'));
  expect(part,isNot(contains('_financeAuthority.saveCaptured(')));
  expect(part,isNot(contains('_financeAuthority.commitConfirmedSms(')));
  expect(main,contains(' bool _autoSmsImportAgain=false;'));
 });
 test('M742 original source contracts see identical registered native SMS refresh',(){
  final src=readWaffraMainSourceForContracts();
  final start=src.indexOf(' Future<void> _refreshAutoSmsInbox(');
  final end=src.indexOf(' Future<void> _scanPreviousBankSmsFromSettings()async{',start);
  final part=File('lib/waffra_home_sms_refresh.part.dart').readAsStringSync();
  final original=part.substring(part.indexOf(' Future<void> _refreshAutoSmsInbox('),
   part.lastIndexOf('\n}')+1);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  expect(src.substring(start,end),original);
 });
}
