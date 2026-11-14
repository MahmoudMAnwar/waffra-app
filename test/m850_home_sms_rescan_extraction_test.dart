import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main() {
 test('M850 original bank SMS notice debounce and user rescan stay registered',(){
  final main=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_sms_rescan.part.dart').readAsStringSync();
  expect(main,contains("part 'waffra_home_sms_rescan.part.dart';"));
  expect(part,startsWith("part of 'main.dart';"));
  expect(part,contains('extension _WaffraHomeSmsRescan on _HomeScreenState'));
  expect(main,isNot(contains(' void _receiveAutoSmsNotice(){')));
  expect(part,contains(' void _receiveAutoSmsNotice(){'));
  expect(part,contains(' Future<void> _rescanAutoSmsInbox('));
  expect(part,contains('Timer(const Duration(milliseconds:900)'));
  expect(part,contains('_m632SmsNoticeTimer'));
  expect(part,contains('_autoSmsRescanRunning'));
  expect(part,contains('No new messages to review'));
  expect(part,contains('Pending messages were not deleted'));
  expect(main,contains(' Timer? _m632SmsNoticeTimer;'));
  expect(part,isNot(contains('_financeAuthority.saveCaptured(')));
  expect(part,isNot(contains('_financeAuthority.commitConfirmedSms(')));
 });
 test('M850 native rescan original Dart source reconstructs without changes',(){
  final full=readWaffraMainSourceForContracts();
  final start=full.indexOf(' void _receiveAutoSmsNotice(){');
  final end=full.indexOf(' Future<void>? _autoSmsRefreshInFlight;',start);
  final part=File('lib/waffra_home_sms_rescan.part.dart').readAsStringSync();
  final source=part.substring(part.indexOf(' void _receiveAutoSmsNotice(){'),
   part.lastIndexOf('\n}')+1);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  expect(full.substring(start,end),source);
 });
}
