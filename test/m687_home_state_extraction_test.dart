import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main(){
 test('M687 original report and profile moved without duplication',(){
  final main=File('lib/main.dart').readAsStringSync();
  final pdf=File('lib/waffra_home_pdf_reports.part.dart').readAsStringSync();
  final profile=File('lib/waffra_home_profile.part.dart').readAsStringSync();
  expect(main,contains("part 'waffra_home_pdf_reports.part.dart';"));
  expect(main,contains("part 'waffra_home_profile.part.dart';"));
  expect(main,isNot(contains(' Future<void> exportEntriesPdf(')));
  expect(main,isNot(contains(' Widget profilePage(){')));
  expect(pdf,contains('extension _WaffraHomeReportModule on _HomeScreenState'));
  expect(profile,contains('extension _WaffraHomeProfileModule on _HomeScreenState'));
  expect(pdf,contains('if(!pdfQuote.verified)'));
  expect(pdf,contains('pdfTransfers=await _m648HomeTransfers(account)'));
  expect(pdf,contains('pdfSavings=await _m649HomeSavings(account)'));
  expect(pdf,contains('waffraGoalDueCashMinor(e)/100'));
  expect(profile,contains('future:_m528SmsEnabled()'));
  expect(profile,isNot(contains('future:_m528CloudConsent()')));
  expect(profile,contains('WaffraLocalAccountMigration('));
 });
 test('M687 real code can be source-audited in original method order',(){
  final s=readWaffraMainSourceForContracts();
  final pdf=s.indexOf(' Future<void> exportEntriesPdf(');
  final next=s.indexOf(' Future<void> _deleteVerifiedEntry(',pdf);
  final profile=s.indexOf(' Widget profilePage(){');
  final nextProfile=s.indexOf(' Widget _addMenuOption({',profile);
  expect(pdf,greaterThan(0));
  expect(next,greaterThan(pdf));
  expect(profile,greaterThan(next));
  expect(nextProfile,greaterThan(profile));
  expect(s.substring(pdf,next),contains('if(!pdfQuote.verified)'));
  expect(s.substring(profile,nextProfile),contains('future:_m528SmsEnabled()'));
 });
}
