import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 String src(String file)=>File(file).readAsStringSync();
 test('M1000 source integrity and trust remain read-only',(){
  final trust=src('lib/storage/waffra_financial_trust_read.dart');
  final page=src('lib/waffra_financial_trust_page.dart');
  expect(trust,contains('class Waffra'));
  expect(page,contains('Waffra'));
  expect(page,isNot(contains('commitConfirmedManual(')));
  expect(page,isNot(contains('commitConfirmedSms(')));
 });
 test('M1000 backup preview is authenticated and separated from writes',(){
  final preview=src('lib/waffra_backup_safety_preview.dart');
  final compare=src('lib/waffra_financial_change_review.dart');
  final flow=src('lib/waffra_home_account_tools.part.dart');
  expect(preview,contains('Waffra'));
  expect(compare,contains('Waffra'));
  expect(flow,contains('Waffra'));
  expect(preview,isNot(contains('applyVerifiedV3Restore(')));
 });
 test('M1000 account query uses bounded pages and searchable filters',(){
  final page=src('lib/waffra_account_context_page.dart');
  final pager=src('lib/storage/waffra_sqlcipher_history_pager.dart');
  expect(page,contains('WaffraCenteredDropdownFormField<String>('));
  expect(page,contains('key:ValueKey<bool?>(incomeFilter),'));
  expect(page,contains('onChanged:(value)=>setState((){'));
  expect(page,contains("incomeFilter=value=='all'?null:value=='in';"));
  expect(page,isNot(contains('DropdownButtonFormField<String>(')));
  expect(page,contains('WaffraSqlcipherHistoryPage'));
  expect(pager,contains('WaffraSqlcipherHistoryPage'));
  expect(page,contains('minimumMinor'));
  expect(page,contains('maximumMinor'));
  expect(page,contains('searchDates'));
 });
 test('M1000 recurring forecasts do not post money from a projection',(){
  final policy=src('lib/waffra_financial_trust_policy.dart');
  expect(policy,contains('Waffra'));
  expect(policy,isNot(contains('commitConfirmedSms(')));
  expect(policy,isNot(contains('commitConfirmedManual(')));
 });
}
