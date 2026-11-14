import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main(){
 test('M770 original verified SMS review/confirm methods only in registered Home part',(){
  final home=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_sms_confirmation.part.dart').readAsStringSync();
  expect(home,contains("part 'waffra_home_sms_confirmation.part.dart';"));
  expect(part,startsWith("part of 'main.dart';"));
  expect(part,contains('extension _WaffraHomeSmsConfirmation on _HomeScreenState'));
  expect(home,isNot(contains(' Future<void> _m565ConfirmSms(')));
  expect(home,isNot(contains(' Future<void> _reviewAutoSmsCandidates(')));
  expect(part,contains(' Future<List<MoneyEntry>> _m593BuildVerifiedEntries('));
  expect(part,contains(' Future<void> _m565ConfirmSms('));
  expect(part,contains(' Widget _m615ReviewDetail('));
  expect(part,contains(' Future<void> _reviewAutoSmsCandidates('));
  expect(part,contains('_financeAuthority.commitConfirmedSms('));
  expect(part,contains('allowDuplicateHashes:false'));
  expect(part,contains('userConfirmed:true'));
  expect(part,contains('bankSmsDate(body)==null'));
  expect(part,contains('WaffraAutoSms.acknowledgeCommitted'));
  expect(part,contains('WaffraAutoSms.acknowledge'));
  expect(home,contains(' void _receiveSharedSms()'));
 });
 test('M770 complete old SMS money and UI source checks inspect exact relocated original code',(){
  final source=readWaffraMainSourceForContracts();
  final from=source.indexOf(' Future<List<MoneyEntry>> _m593BuildVerifiedEntries(');
  final to=source.indexOf(' void _receiveSharedSms()',from);
  final file=File('lib/waffra_home_sms_confirmation.part.dart').readAsStringSync();
  final exact=file.substring(file.indexOf(' Future<List<MoneyEntry>> _m593BuildVerifiedEntries('),
   file.lastIndexOf('\n}')+1);
  expect(from,greaterThan(0));
  expect(to,greaterThan(from));
  expect(source.substring(from,to),exact);
 });
}
